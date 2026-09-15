@preconcurrency import Darwin
import Foundation

private struct Request: Decodable {
    let version: Int
    let audioPath: String
    let modelPath: String?
    let modelID: String?
    let engine: String?
    let repository: String?
    let modelDirectory: String?
    let entryFile: String?
    let language: String
    let outputStyle: String?
}

private struct Event: Encodable {
    let type: String
    var stage: String?
    var progress: Double?
    var text: String?
    var detectedLanguage: String?
    var segments: [HelperSegment]?
    var code: String?
    var message: String?
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
            guard request.version == 1 || request.version == 2 else {
                throw CLIError("unsupported_protocol", "The helper protocol version is unsupported.")
            }

            let audioURL = URL(fileURLWithPath: request.audioPath)
            let cancellation = SignalCancellation()
            output.send(Event(type: "stage", stage: "validating"))
            let decoder = AudioDecoder()
            let selection = try await decoder.inspect(audioURL)

            output.send(Event(type: "stage", stage: "decoding"))
            let samples = try await decoder.decode(selection) { progress in
                output.send(Event(type: "progress", stage: "decoding", progress: progress))
            }

            output.send(Event(type: "stage", stage: "transcribing"))
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
                    cancellation: cancellation.transcription
                ) { progress in
                    let fraction = min(max(Double(progress) / 100.0, 0), 1)
                    output.send(Event(type: "progress", stage: "transcribing", progress: fraction))
                }
                output.send(Event(type: "result", text: result.text, detectedLanguage: result.detectedLanguage))
            } else {
                guard request.version == 2,
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
                output.send(Event(
                    type: "result",
                    text: result.text,
                    detectedLanguage: result.detectedLanguage,
                    segments: result.segments.isEmpty ? nil : result.segments
                ))
            }
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
