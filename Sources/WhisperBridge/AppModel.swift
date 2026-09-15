import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

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

    private let modelStore: ModelStore
    private let downloader: ModelDownloader
    private let decoder: AudioDecoder
    private let engine: WhisperEngine
    private var workTask: Task<Void, Never>?
    private var transcriptionCancellation: TranscriptionCancellation?
    private var scopedURL: URL?
    private var hasScopedAccess = false

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
        Task { await refreshModelState() }
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

    func transcribe() {
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
                let samples = try await decoder.decode(selection) { value in
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
                    cancellation: cancellation
                ) { value in
                    Task { @MainActor [weak self] in
                        guard let self, self.phase == .transcribing else { return }
                        self.progress = Double(value) / 100
                    }
                }
                try Task.checkCancellation()
                transcript = Transcript(rawText: result.text, editedText: result.text, detectedLanguage: result.detectedLanguage)
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

    func cancelWork() {
        transcriptionCancellation?.cancel()
        workTask?.cancel()
        statusMessage = "Cancelling…"
    }

    func resetTranscript() {
        guard var current = transcript, current.isDirty else { return }
        guard confirmDiscard(title: "Reset your edits?", detail: "This restores Whisper’s original transcript.") else { return }
        current.editedText = current.rawText
        transcript = current
        statusMessage = "Edits reset to the original transcript."
    }

    func clearTranscript() {
        if transcriptIsDirty, !confirmDiscard(title: "Clear edited transcript?", detail: "Your edits have not been saved.") {
            return
        }
        transcript = nil
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
