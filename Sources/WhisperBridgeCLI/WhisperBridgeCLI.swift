@preconcurrency import Darwin
import Foundation

private struct Request: Decodable {
    let version: Int
    let audioPath: String
    let modelPath: String
    let language: String
}

private struct Event: Encodable {
    let type: String
    var stage: String?
    var progress: Double?
    var text: String?
    var detectedLanguage: String?
    var code: String?
    var message: String?
}

private final class Output: @unchecked Sendable {
    private let lock = NSLock()
    private let encoder = JSONEncoder()

    func send(_ event: Event) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? encoder.encode(event) else { return }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
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
        do {
            let requestData = FileHandle.standardInput.readDataToEndOfFile()
            let request = try JSONDecoder().decode(Request.self, from: requestData)
            guard request.version == 1 else {
                throw CLIError("unsupported_protocol", "The helper protocol version is unsupported.")
            }
            guard let language = LanguageOption(rawValue: request.language) else {
                throw CLIError("invalid_language", "The selected language is unsupported.")
            }

            let audioURL = URL(fileURLWithPath: request.audioPath)
            let modelURL = URL(fileURLWithPath: request.modelPath)
            guard FileManager.default.isReadableFile(atPath: modelURL.path) else {
                throw AppFailure.modelUnavailable
            }

            let cancellation = SignalCancellation()
            output.send(Event(type: "stage", stage: "validating"))
            let decoder = AudioDecoder()
            let selection = try await decoder.inspect(audioURL)

            output.send(Event(type: "stage", stage: "decoding"))
            let samples = try await decoder.decode(selection) { progress in
                output.send(Event(type: "progress", stage: "decoding", progress: progress))
            }

            output.send(Event(type: "stage", stage: "transcribing"))
            let result = try await WhisperEngine().transcribe(
                samples: samples,
                modelURL: modelURL,
                language: language,
                cancellation: cancellation.transcription
            ) { progress in
                let fraction = min(max(Double(progress) / 100.0, 0), 1)
                output.send(Event(type: "progress", stage: "transcribing", progress: fraction))
            }
            output.send(Event(
                type: "result",
                text: result.text,
                detectedLanguage: result.detectedLanguage
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
            output.send(Event(type: "error", code: "unexpected", message: "Transcription failed unexpectedly."))
            Darwin.exit(2)
        }
    }
}

private struct CLIError: Error {
    let code: String
    let message: String

    init(_ code: String, _ message: String) {
        self.code = code
        self.message = message
    }
}
