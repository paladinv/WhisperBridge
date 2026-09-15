import AppKit
import AVFoundation
import Combine
import Foundation
import UniformTypeIdentifiers
import WhisperBridgeCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var phase: AppPhase = .checkingModel
    @Published private(set) var isModelInstalled = false
    @Published private(set) var selection: AudioSelection?
    @Published private(set) var transcript: Transcript?
    @Published private(set) var progress = 0.0
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage = "Checking the local speech model."
    @Published var language: LanguageOption = .auto
    @Published private(set) var library: [TranscriptSummary] = []
    @Published var currentDocument: TranscriptDocument?
    @Published var searchText = ""
    @Published private(set) var searchResults: [TranscriptSearchResult] = []
    @Published var selectedSegmentIDs: Set<UUID> = []
    @Published var compactMode = false
    @Published var hideFillers = false
    @Published var timestampGranularity: TimestampGranularity = .segment
    @Published var decodingPreset: DecodingPreset = .balanced
    @Published var decodingOptions = DecodingPreset.balanced.options
    @Published var diarizationEnabled = false
    @Published var rangeStart = 0.0
    @Published var rangeEnd = 0.0

    private let modelStore: ModelStore
    private let downloader: ModelDownloader
    private let decoder: AudioDecoder
    private let engine: WhisperEngine
    private let transcriptStore: TranscriptStore?
    private var workTask: Task<Void, Never>?
    private var transcriptionCancellation: TranscriptionCancellation?
    private var scopedURL: URL?
    private var hasScopedAccess = false
    private var player: AVPlayer?
    private var pendingEditSave: Task<Void, Never>?

    init(
        modelStore: ModelStore = ModelStore(),
        downloader: ModelDownloader = ModelDownloader(),
        decoder: AudioDecoder = AudioDecoder(),
        engine: WhisperEngine = WhisperEngine()
    ) {
        self.modelStore = modelStore
        self.downloader = downloader
        self.decoder = decoder
        self.engine = engine
        transcriptStore = try? TranscriptStore()
        Task { await refreshModelState() }
        refreshLibrary()
    }

    deinit {
        if hasScopedAccess { scopedURL?.stopAccessingSecurityScopedResource() }
    }

    var isBusy: Bool {
        switch phase {
        case .checkingModel, .downloadingModel, .inspectingAudio, .decoding, .transcribing: true
        default: false
        }
    }

    var canTranscribe: Bool { isModelInstalled && selection != nil && !isBusy }
    var hasTranscript: Bool { !(transcript?.editedText.isEmpty ?? true) }
    var transcriptIsDirty: Bool { transcript?.isDirty == true }

    var editedText: String {
        get { transcript?.editedText ?? "" }
        set {
            guard var current = transcript else { return }
            current.editedText = newValue
            transcript = current
        }
    }

    var characterCount: String {
        let count = editedText.count
        return "\(count.formatted()) character\(count == 1 ? "" : "s")"
    }

    func refreshModelState() async {
        phase = .checkingModel
        statusMessage = "Verifying the local speech model."
        isModelInstalled = await modelStore.isInstalled()
        phase = isModelInstalled ? .ready : .needsModel
        statusMessage = isModelInstalled ? "Speech model ready." : "Download the speech model once to transcribe locally."
    }

    func downloadModel() {
        guard !isBusy else { return }
        clearError()
        phase = .downloadingModel
        statusMessage = "Downloading and verifying \(ModelManifest.recommended.formattedSize)."
        progress = 0
        workTask = Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await downloader.download(.recommended)
                try Task.checkCancellation()
                statusMessage = "Verifying the speech model."
                try await modelStore.install(data)
                isModelInstalled = true
                phase = .ready
                statusMessage = "Speech model ready. Choose an audio file."
            } catch is CancellationError {
                phase = .needsModel
                statusMessage = "Model download cancelled."
            } catch {
                show(error)
            }
            workTask = nil
        }
    }

    func chooseAudio() {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose an audio file"
        panel.prompt = "Choose Audio"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType.wav,
            UTType.mp3,
            UTType.mpeg4Audio,
            UTType(filenameExtension: "aac") ?? .audio,
            UTType(filenameExtension: "flac") ?? .audio,
        ]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        requestImport(url)
    }

    func importTranscriptFile() {
        let panel = NSOpenPanel()
        panel.title = "Import transcript or STTTTS project"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "tst")!, UTType(filenameExtension: "srt")!, UTType(filenameExtension: "vtt")!, .plainText, .json, .commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url, let store = transcriptStore else { return }
        do {
            let document: TranscriptDocument
            switch url.pathExtension.lowercased() {
            case "tst": document = try TSTArchiveService.importProject(from: url, into: store)
            case "json":
                var imported = try JSONDecoder().decode(TranscriptDocument.self, from: Data(contentsOf: url))
                // An exported asset identifier belongs to the source library and
                // cannot safely reference this library without importing audio.
                imported.audioAssetID = nil
                document = imported
            case "csv":
                document = try CSVTranscriptCodec.parse(
                    String(contentsOf: url, encoding: .utf8),
                    title: url.deletingPathExtension().lastPathComponent,
                    sourceFilename: url.lastPathComponent
                )
            case "srt", "vtt":
                let format: SubtitleFormat = url.pathExtension.lowercased() == "srt" ? .srt : .vtt
                let segments = try SubtitleCodec.parse(String(contentsOf: url, encoding: .utf8), format: format)
                document = TranscriptDocument(title: url.deletingPathExtension().lastPathComponent, sourceFilename: url.lastPathComponent, duration: segments.map(\.end).max() ?? 0, modelID: "subtitle-import", segments: segments)
            default:
                let text = try String(contentsOf: url, encoding: .utf8)
                document = TranscriptDocument(title: url.deletingPathExtension().lastPathComponent, sourceFilename: url.lastPathComponent, duration: 0, modelID: "text-import", timestampGranularity: .none, segments: [TranscriptSegment(start: 0, end: 0, rawText: text)])
            }
            try store.save(document)
            refreshLibrary(); selectTranscript(document.id)
            statusMessage = "Imported \(url.lastPathComponent)."
        } catch { show(error) }
    }

    func receiveDrop(_ urls: [URL]) {
        guard !isBusy else { return }
        guard urls.count == 1, let url = urls.first else {
            show(AppFailure.decodeFailed("Choose one audio file at a time."))
            return
        }
        requestImport(url)
    }

    private func requestImport(_ url: URL) {
        if transcriptIsDirty, !confirmDiscard(title: "Replace edited transcript?", detail: "Your edits have not been saved. Choose Cancel to keep working on them.") {
            return
        }
        inspectAudio(url)
    }

    private func inspectAudio(_ url: URL) {
        clearError()
        phase = .inspectingAudio
        statusMessage = "Checking \(url.lastPathComponent)."
        let gainedAccess = url.startAccessingSecurityScopedResource()
        workTask = Task { [weak self] in
            guard let self else {
                if gainedAccess { url.stopAccessingSecurityScopedResource() }
                return
            }
            do {
                let inspected = try await decoder.inspect(url)
                releaseCurrentScope()
                scopedURL = url
                hasScopedAccess = gainedAccess
                selection = inspected
                rangeStart = 0
                rangeEnd = inspected.duration
                transcript = nil
                phase = isModelInstalled ? .ready : .needsModel
                statusMessage = isModelInstalled ? "Audio ready to transcribe." : "Audio selected. Download the speech model to continue."
            } catch {
                if gainedAccess { url.stopAccessingSecurityScopedResource() }
                show(error)
            }
            workTask = nil
        }
    }

    func transcribe() { transcribe(range: nil) }

    func transcribeSelection() {
        guard let selection else { return }
        do { transcribe(range: try TranscriptTimeRange(start: rangeStart, end: rangeEnd).validated(duration: selection.duration)) }
        catch { show(error) }
    }

    private func transcribe(range: TranscriptTimeRange?) {
        guard canTranscribe, let selection else { return }
        if transcriptIsDirty, !confirmDiscard(title: "Transcribe again?", detail: "Transcribing again replaces your edited transcript.") {
            return
        }
        clearError()
        let cancellation = TranscriptionCancellation()
        transcriptionCancellation = cancellation
        progress = 0
        phase = .decoding
        statusMessage = "Preparing audio locally."

        workTask = Task { [weak self] in
            guard let self else { return }
            do {
                let samples = try await decoder.decode(selection, range: range) { value in
                    Task { @MainActor [weak self] in
                        guard let self, self.phase == .decoding else { return }
                        self.progress = value
                    }
                }
                try Task.checkCancellation()
                phase = .transcribing
                progress = 0
                statusMessage = "Whisper is transcribing locally."
                let result = try await engine.transcribe(
                    samples: samples,
                    modelURL: await modelStore.modelURL,
                    language: language,
                    timestampGranularity: timestampGranularity,
                    decodingOptions: decodingOptions,
                    timeOffset: range?.start ?? 0,
                    cancellation: cancellation
                ) { value in
                    Task { @MainActor [weak self] in
                        guard let self, self.phase == .transcribing else { return }
                        self.progress = Double(value) / 100
                    }
                }
                try Task.checkCancellation()
                var recognizedSegments = result.segments
                var detectedSpeakers: [TranscriptSpeaker] = []
                if diarizationEnabled {
                    guard #available(macOS 15.0, *) else { throw TranscriptCoreError.invalidSetting("Speaker diarization requires macOS 15 or newer.") }
                    statusMessage = "Detecting speakers locally."
                    let directory = TranscriptStore.defaultDirectory().appending(path: "models/fluid-audio-diarization/0.15.5", directoryHint: .isDirectory)
                    let diarization = try await DiarizationService.process(samples: samples, modelDirectory: directory, timeOffset: range?.start ?? 0)
                    detectedSpeakers = diarization.speakers
                    recognizedSegments = DiarizationService.applying(diarization, to: recognizedSegments)
                }
                if let range, var existing = currentDocument {
                    TranscriptEditing.replace(range: range, with: recognizedSegments, in: &existing)
                    for speaker in detectedSpeakers where !existing.speakers.contains(where: { $0.id == speaker.id }) { existing.speakers.append(speaker) }
                    existing.timestampGranularity = timestampGranularity
                    existing.decodingOptions = decodingOptions
                    currentDocument = existing
                } else {
                    let asset = try transcriptStore?.importAudio(from: selection.url, duration: selection.duration)
                    currentDocument = TranscriptDocument(
                        title: selection.url.deletingPathExtension().lastPathComponent,
                        sourceFilename: selection.displayName,
                        audioAssetID: asset?.id,
                        duration: selection.duration,
                        detectedLanguage: result.detectedLanguage,
                        modelID: "whisper-base-multilingual",
                        timestampGranularity: timestampGranularity,
                        decodingOptions: decodingOptions,
                        speakers: detectedSpeakers,
                        segments: recognizedSegments
                    )
                }
                if hideFillers, var document = currentDocument {
                    for index in document.segments.indices { document.segments[index].fillersHidden = true }
                    currentDocument = document
                }
                if let document = currentDocument { try transcriptStore?.save(document) }
                refreshLibrary()
                let displayed = currentDocument?.activeText ?? result.text
                transcript = Transcript(rawText: result.text, editedText: displayed, detectedLanguage: result.detectedLanguage)
                phase = .review
                progress = 1
                statusMessage = result.detectedLanguage.map { "Transcript ready · \($0)" } ?? "Transcript ready."
            } catch is CancellationError {
                phase = .ready
                progress = 0
                statusMessage = "Transcription cancelled."
            } catch {
                show(error)
            }
            transcriptionCancellation = nil
            workTask = nil
        }
    }

    func selectTranscript(_ id: UUID) {
        do {
            currentDocument = try transcriptStore?.load(id: id)
            if let document = currentDocument {
                transcript = Transcript(rawText: document.segments.map(\.rawText).joined(separator: "\n"), editedText: document.activeText, detectedLanguage: document.detectedLanguage)
                selection = document.audioAssetID.flatMap { try? transcriptStore?.audioURL(assetID: $0) }.flatMap { $0 }.flatMap { url in
                    try? AudioSelection(url: url, displayName: document.sourceFilename, byteCount: Int64(url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0), duration: document.duration)
                }
                rangeStart = 0; rangeEnd = document.duration
                timestampGranularity = document.timestampGranularity
                decodingOptions = document.decodingOptions
                phase = .review
            }
        } catch { show(error) }
    }

    func searchLibrary() {
        do { searchResults = try transcriptStore?.search(searchText) ?? [] }
        catch { show(error) }
    }

    func updateSegment(id: UUID, text: String) {
        guard var document = currentDocument, let index = document.segments.firstIndex(where: { $0.id == id }) else { return }
        document.segments[index].editedText = text
        document.updatedAt = Date()
        currentDocument = document
        transcript = Transcript(rawText: document.segments.map(\.rawText).joined(separator: "\n"), editedText: document.activeText, detectedLanguage: document.detectedLanguage)
        pendingEditSave?.cancel()
        pendingEditSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self, let latest = self.currentDocument else { return }
            do { try self.transcriptStore?.save(latest); self.refreshLibrary() }
            catch { self.show(error) }
        }
    }

    func deleteSelectedSegments() { mutateDocument { TranscriptEditing.delete(selectedSegmentIDs, in: &$0) } }
    func restoreSelectedSegments() { mutateDocument { TranscriptEditing.restore(selectedSegmentIDs, in: &$0) } }
    func mergeSelectedSegments() { do { try mutateDocumentThrowing { try TranscriptEditing.merge(selectedSegmentIDs, in: &$0) } } catch { show(error) } }
    func splitSelectedSegment() {
        guard selectedSegmentIDs.count == 1, let id = selectedSegmentIDs.first,
              let segment = currentDocument?.segments.first(where: { $0.id == id }) else { return }
        do { try mutateDocumentThrowing { try TranscriptEditing.split(segmentID: id, at: (segment.start + segment.end) / 2, in: &$0) }; selectedSegmentIDs = [] }
        catch { show(error) }
    }

    func addSpeaker() {
        mutateDocument { document in
            document.speakers.append(TranscriptSpeaker(name: "Speaker \(document.speakers.count + 1)", colorIndex: document.speakers.count))
        }
    }

    func renameSpeaker(_ id: UUID, name: String) {
        mutateDocument { document in
            if let index = document.speakers.firstIndex(where: { $0.id == id }) { document.speakers[index].name = name }
        }
    }

    func mergeSpeaker(_ sourceID: UUID, into destinationID: UUID) {
        guard sourceID != destinationID else { return }
        mutateDocument { document in
            for index in document.segments.indices where document.segments[index].speakerID == sourceID { document.segments[index].speakerID = destinationID }
            document.speakers.removeAll { $0.id == sourceID }
        }
    }

    func assignSpeaker(_ id: UUID?) { mutateDocument { TranscriptEditing.assignSpeaker(id, to: selectedSegmentIDs, in: &$0) } }

    func setFillersHidden(_ hidden: Bool) {
        hideFillers = hidden
        mutateDocument { document in
            for index in document.segments.indices { document.segments[index].fillersHidden = hidden }
        }
    }

    func applyPreset(_ preset: DecodingPreset) {
        decodingPreset = preset
        decodingOptions = preset.options
    }

    func copyDocumentForLMStudio() {
        guard let document = currentDocument else { copyTranscript(); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(TranscriptFormatting.renderedSegments(document, compact: compactMode), forType: .string)
        statusMessage = "Copied the structured transcript for LM Studio."
    }

    func exportDocument() {
        guard let document = currentDocument else { saveTranscript(); return }
        let panel = NSSavePanel()
        panel.title = "Export transcript"
        panel.nameFieldStringValue = "\(document.title).md"
        panel.allowedContentTypes = [.plainText, .json, .commaSeparatedText, UTType(filenameExtension: "md")!, UTType(filenameExtension: "srt")!, UTType(filenameExtension: "vtt")!, UTType(filenameExtension: "tst")!]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let audioURL = try document.audioAssetID.flatMap { try transcriptStore?.audioURL(assetID: $0) }
            switch url.pathExtension.lowercased() {
            case "tst": try TSTArchiveService.exportProject(document, audioURL: audioURL, to: url)
            case "srt": try SubtitleCodec.serialize(document.segments, format: .srt).write(to: url, atomically: true, encoding: .utf8)
            case "vtt": try SubtitleCodec.serialize(document.segments, format: .vtt).write(to: url, atomically: true, encoding: .utf8)
            case "json": try JSONEncoder().encode(document).write(to: url, options: .atomic)
            case "csv": try CSVTranscriptCodec.serialize(document).write(to: url, atomically: true, encoding: .utf8)
            default: try TranscriptFormatting.renderedSegments(document, compact: compactMode).write(to: url, atomically: true, encoding: .utf8)
            }
            statusMessage = "Exported \(url.lastPathComponent)."
        } catch { show(error) }
    }

    private func refreshLibrary() { library = (try? transcriptStore?.list()) ?? [] }

    private func persist(_ document: TranscriptDocument) {
        pendingEditSave?.cancel()
        pendingEditSave = nil
        currentDocument = document
        transcript = Transcript(rawText: document.segments.map(\.rawText).joined(separator: "\n"), editedText: document.activeText, detectedLanguage: document.detectedLanguage)
        do { try transcriptStore?.save(document); refreshLibrary() } catch { show(error) }
    }

    private func mutateDocument(_ operation: (inout TranscriptDocument) -> Void) {
        guard var document = currentDocument else { return }
        operation(&document); document.updatedAt = Date(); persist(document)
    }

    private func mutateDocumentThrowing(_ operation: (inout TranscriptDocument) throws -> Void) throws {
        guard var document = currentDocument else { return }
        try operation(&document); document.updatedAt = Date(); persist(document)
    }

    func cancelWork() {
        transcriptionCancellation?.cancel()
        workTask?.cancel()
        statusMessage = "Cancelling…"
    }

    func playPause() {
        guard let url = selection?.url else { return }
        if player == nil { player = AVPlayer(url: url) }
        if player?.rate == 0 { player?.play(); statusMessage = "Playing audio." }
        else { player?.pause(); statusMessage = "Audio paused." }
    }

    func resetTranscript() {
        let structuredDirty = currentDocument?.segments.contains { $0.editedText != $0.rawText || $0.isDeleted || $0.fillersHidden } == true
        guard transcript?.isDirty == true || structuredDirty else { return }
        guard confirmDiscard(title: "Reset your edits?", detail: "This restores Whisper’s original transcript.") else { return }
        if currentDocument != nil {
            mutateDocument { document in
                for index in document.segments.indices {
                    document.segments[index].editedText = document.segments[index].rawText
                    document.segments[index].isDeleted = false
                    document.segments[index].fillersHidden = false
                }
            }
            hideFillers = false
        } else if var current = transcript {
            current.editedText = current.rawText
            transcript = current
        }
        statusMessage = "Edits reset to the original transcript."
    }

    func clearTranscript() {
        if transcriptIsDirty, !confirmDiscard(title: "Clear edited transcript?", detail: "Your edits have not been saved.") {
            return
        }
        transcript = nil
        currentDocument = nil
        selectedSegmentIDs = []
        progress = 0
        phase = isModelInstalled ? .ready : .needsModel
        statusMessage = selection == nil ? "Choose an audio file." : "Audio ready to transcribe."
    }

    func copyTranscript() {
        guard hasTranscript else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(editedText, forType: .string)
        statusMessage = "Copied. Paste into the LM Studio prompt when you are ready."
    }

    func saveTranscript() {
        guard hasTranscript else { return }
        let panel = NSSavePanel()
        panel.title = "Save transcript"
        panel.nameFieldStringValue = suggestedTranscriptName
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try editedText.write(to: destination, atomically: true, encoding: .utf8)
            statusMessage = "Transcript saved to \(destination.lastPathComponent)."
        } catch {
            show(AppFailure.saveFailed(error.localizedDescription))
        }
    }

    func dismissError() {
        clearError()
        phase = transcript != nil ? .review : (isModelInstalled ? .ready : .needsModel)
        statusMessage = selection == nil ? "Choose an audio file." : "Ready to continue."
    }

    private var suggestedTranscriptName: String {
        let base = selection?.url.deletingPathExtension().lastPathComponent ?? "Transcript"
        return base + " transcript.txt"
    }

    private func show(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        phase = .failed
        progress = 0
        statusMessage = "The current step could not be completed."
    }

    private func clearError() { errorMessage = nil }

    private func releaseCurrentScope() {
        if hasScopedAccess { scopedURL?.stopAccessingSecurityScopedResource() }
        scopedURL = nil
        hasScopedAccess = false
    }

    private func confirmDiscard(title: String, detail: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
