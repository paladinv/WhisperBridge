@preconcurrency import Darwin
import Foundation
import WhisperBridgeCore

private struct Request: Decodable {
    let version: Int
    let action: String?
    let audioPath: String?
    let modelPath: String?
    let modelID: String?
    let engine: String?
    let repository: String?
    let modelDirectory: String?
    let entryFile: String?
    let language: String
    let outputStyle: String?
    let timeRange: TranscriptTimeRange?
    let timestampGranularity: TimestampGranularity?
    let diarization: Bool?
    let diarizationModelDirectory: String?
    let decodingOptions: WhisperDecodingOptions?
    let library: LibraryRequest?
    let query: String?
    let speaker: String?
    let transcriptID: String?
    let start: Double?
    let end: Double?
    let limit: Int?
}

private struct LibraryRequest: Decodable {
    let enabled: Bool
    let dataDirectory: String?
    let title: String?
}

private struct Event: Encodable {
    let type: String
    var stage: String?
    var progress: Double?
    var text: String?
    var detectedLanguage: String?
    var segments: [HelperSegment]?
    var speakers: [HelperSpeaker]?
    var duration: Double?
    var transcriptID: String?
    var code: String?
    var message: String?
}

private struct HelperSpeaker: Encodable {
    let id: String
    let name: String
}

private struct SearchResultPayload: Encodable {
    let transcriptID: String
    let segmentID: String
    let title: String
    let speaker: String?
    let snippet: String
    let start: Double
    let rank: Double
}

private final class Output: @unchecked Sendable {
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let handle: FileHandle

    init() {
        let descriptor = Darwin.dup(STDOUT_FILENO)
        handle = descriptor >= 0
            ? FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            : FileHandle.standardOutput
    }

    func send(_ event: Event) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? encoder.encode(event) else { return }
        handle.write(data)
        handle.write(Data([0x0A]))
    }
}

private final class SignalCancellation: @unchecked Sendable {
    let transcription = TranscriptionCancellation()
    private var sources: [DispatchSourceSignal] = []

    init() {
        for signalNumber in [SIGINT, SIGTERM] {
            Darwin.signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler { [transcription] in transcription.cancel() }
            source.resume()
            sources.append(source)
        }
    }
}

@main
private struct WhisperBridgeCLI {
    static func main() async {
        let output = Output()
        // Third-party inference libraries use print() for diagnostics. Keep stdout reserved
        // for the JSON-lines helper protocol and send library diagnostics to stderr.
        _ = Darwin.dup2(STDERR_FILENO, STDOUT_FILENO)
        do {
            let requestData = FileHandle.standardInput.readDataToEndOfFile()
            let request = try JSONDecoder().decode(Request.self, from: requestData)
            guard (1...3).contains(request.version) else {
                throw CLIError("unsupported_protocol", "The helper protocol version is unsupported.")
            }

            if request.action == "search_transcripts" {
                let store = try TranscriptStore(directory: request.library?.dataDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? TranscriptStore.defaultDirectory())
                let results = try store.search(request.query ?? "", speaker: request.speaker, limit: min(max(request.limit ?? 20, 1), 50))
                let payload = results.map { SearchResultPayload(transcriptID: $0.transcriptID.uuidString, segmentID: $0.segmentID.uuidString, title: $0.title, speaker: $0.speakerName, snippet: $0.snippet, start: $0.start, rank: $0.rank) }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let data = try encoder.encode(payload)
                output.send(Event(type: "result", text: String(data: data, encoding: .utf8) ?? "[]"))
                return
            }
            if request.action == "get_transcript_excerpt" {
                guard let id = request.transcriptID.flatMap(UUID.init(uuidString:)) else { throw CLIError("invalid_transcript", "A valid transcript ID is required.") }
                let store = try TranscriptStore(directory: request.library?.dataDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? TranscriptStore.defaultDirectory())
                guard let document = try store.load(id: id) else { throw CLIError("not_found", "The transcript was not found.") }
                let lower = max(0, request.start ?? 0)
                let upper = min(document.duration, request.end ?? document.duration)
                guard upper > lower else { throw CLIError("invalid_range", "The excerpt end must be after its start.") }
                let excerpt = document.segments.filter { !$0.isDeleted && $0.start < upper && $0.end > lower }.prefix(min(max(request.limit ?? 40, 1), 100))
                let copy = TranscriptDocument(title: document.title, sourceFilename: document.sourceFilename, duration: document.duration, modelID: document.modelID, speakers: document.speakers, segments: Array(excerpt))
                output.send(Event(type: "result", text: String(TranscriptFormatting.renderedSegments(copy, compact: false).prefix(12_000))))
                return
            }
            if request.action == "inspect_audio" {
                guard let audioPath = request.audioPath else { throw CLIError("malformed_request", "The audio path is required.") }
                let selection = try await AudioDecoder().inspect(URL(fileURLWithPath: audioPath))
                output.send(Event(type: "result", text: "ok", duration: selection.duration))
                return
            }

            guard let audioPath = request.audioPath else { throw CLIError("malformed_request", "The audio path is required.") }
            let audioURL = URL(fileURLWithPath: audioPath)
            let cancellation = SignalCancellation()
            output.send(Event(type: "stage", stage: "validating"))
            let decoder = AudioDecoder()
            let selection = try await decoder.inspect(audioURL)

            output.send(Event(type: "stage", stage: "decoding"))
            let range = try request.timeRange?.validated(duration: selection.duration)
            let samples = try await decoder.decode(selection, range: range) { progress in
                output.send(Event(type: "progress", stage: "decoding", progress: progress))
            }

            output.send(Event(type: "stage", stage: "transcribing"))
            var text: String
            var detectedLanguage: String?
            var coreSegments: [TranscriptSegment]
            var speakers: [TranscriptSpeaker] = []
            if request.version == 1 || request.engine == "whisperCpp" {
                guard let language = LanguageOption(rawValue: request.language) else {
                    throw CLIError("invalid_language", "The selected language is unsupported.")
                }
                let path: String
                if request.version == 1 {
                    guard let modelPath = request.modelPath else { throw AppFailure.modelUnavailable }
                    path = modelPath
                } else {
                    guard let modelDirectory = request.modelDirectory, let entryFile = request.entryFile else {
                        throw AppFailure.modelUnavailable
                    }
                    path = URL(fileURLWithPath: modelDirectory).appendingPathComponent(entryFile).path
                }
                let modelURL = URL(fileURLWithPath: path)
                guard FileManager.default.isReadableFile(atPath: modelURL.path) else {
                    throw AppFailure.modelUnavailable
                }
                let result = try await WhisperEngine().transcribe(
                    samples: samples,
                    modelURL: modelURL,
                    language: language,
                    timestampGranularity: request.timestampGranularity ?? .segment,
                    decodingOptions: request.decodingOptions ?? DecodingPreset.balanced.options,
                    timeOffset: range?.start ?? 0,
                    cancellation: cancellation.transcription
                ) { progress in
                    let fraction = min(max(Double(progress) / 100.0, 0), 1)
                    output.send(Event(type: "progress", stage: "transcribing", progress: fraction))
                }
                text = result.text
                detectedLanguage = result.detectedLanguage
                coreSegments = result.segments
            } else {
                guard request.version >= 2,
                      let engine = request.engine,
                      let repository = request.repository,
                      let modelDirectory = request.modelDirectory else {
                    throw CLIError("malformed_request", "The version 2 model request is incomplete.")
                }
                let result = try await MLXEngine().transcribe(
                    samples: samples,
                    engine: engine,
                    repository: repository,
                    modelDirectory: URL(fileURLWithPath: modelDirectory),
                    language: request.language,
                    outputStyle: request.outputStyle ?? "plain"
                )
                text = result.text
                detectedLanguage = result.detectedLanguage
                let offset = range?.start ?? 0
                let decodedDuration = Double(samples.count) / AudioDecoder.targetSampleRate
                coreSegments = result.segments.map { item in
                    TranscriptSegment(
                        start: (item.start ?? 0) + offset,
                        end: max((item.start ?? 0) + offset, (item.end ?? decodedDuration) + offset),
                        rawText: item.text,
                        timingIsApproximate: item.start == nil || item.end == nil
                    )
                }
                if coreSegments.isEmpty {
                    coreSegments = [TranscriptSegment(start: range?.start ?? 0, end: range?.end ?? selection.duration, rawText: text, timingIsApproximate: true)]
                }
            }

            if request.diarization == true {
                guard #available(macOS 15.0, *) else {
                    throw CLIError("unsupported_macos", "Speaker diarization requires macOS 15 or newer.")
                }
                guard let directory = request.diarizationModelDirectory else {
                    throw CLIError("model_unavailable", "Install the verified FluidAudio diarization assets before enabling speaker detection.")
                }
                output.send(Event(type: "stage", stage: "diarizing"))
                let diarization = try await DiarizationService.process(
                    samples: samples,
                    modelDirectory: URL(fileURLWithPath: directory),
                    timeOffset: range?.start ?? 0
                ) { fraction in
                    output.send(Event(type: "progress", stage: "diarizing", progress: fraction))
                }
                speakers = diarization.speakers
                coreSegments = DiarizationService.applying(diarization, to: coreSegments)
            }

            var transcriptID: String?
            if request.version == 3, request.library?.enabled == true {
                let libraryDirectory = request.library?.dataDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) }
                let store = try TranscriptStore(directory: libraryDirectory ?? TranscriptStore.defaultDirectory())
                let asset = try store.importAudio(from: audioURL, duration: selection.duration)
                let document = TranscriptDocument(
                    title: request.library?.title ?? audioURL.deletingPathExtension().lastPathComponent,
                    sourceFilename: audioURL.lastPathComponent,
                    audioAssetID: asset.id,
                    duration: selection.duration,
                    detectedLanguage: detectedLanguage,
                    modelID: request.modelID ?? "whisper-base-multilingual",
                    sourceRange: range,
                    timestampGranularity: request.timestampGranularity ?? .segment,
                    decodingOptions: request.decodingOptions ?? DecodingPreset.balanced.options,
                    speakers: speakers,
                    segments: coreSegments
                )
                try store.save(document)
                transcriptID = document.id.uuidString
            }

            let speakerNames = Dictionary(uniqueKeysWithValues: speakers.map { ($0.id, $0.name) })
            let helperSegments = coreSegments.map { item in
                HelperSegment(
                    start: item.start, end: item.end, text: item.displayText,
                    speaker: item.speakerID.flatMap { speakerNames[$0] },
                    words: item.words.map { HelperWord(start: $0.start, end: $0.end, text: $0.rawText) },
                    overlap: item.hasOverlappingSpeech
                )
            }
            output.send(Event(
                type: "result", text: text, detectedLanguage: detectedLanguage,
                segments: helperSegments, speakers: speakers.map { HelperSpeaker(id: $0.id.uuidString, name: $0.name) },
                duration: selection.duration, transcriptID: transcriptID
            ))
        } catch is CancellationError {
            output.send(Event(type: "error", code: "cancelled", message: "Transcription was cancelled."))
            Darwin.exit(130)
        } catch let error as CLIError {
            output.send(Event(type: "error", code: error.code, message: error.message))
            Darwin.exit(2)
        } catch let error as AppFailure {
            output.send(Event(
                type: "error",
                code: String(describing: error),
                message: error.errorDescription ?? "Transcription failed."
            ))
            Darwin.exit(2)
        } catch {
            let detail = String(error.localizedDescription.prefix(500))
                .replacingOccurrences(of: "\n", with: " ")
            output.send(Event(
                type: "error",
                code: "unexpected",
                message: detail.isEmpty ? "Transcription failed unexpectedly." : "Transcription failed: \(detail)"
            ))
            Darwin.exit(2)
        }
    }
}

struct CLIError: Error {
    let code: String
    let message: String

    init(_ code: String, _ message: String) {
        self.code = code
        self.message = message
    }
}
