import XCTest

final class PerformanceTests: XCTestCase {
    func testPinnedModelHashCompletesWithinBudget() async throws {
        let modelURL = Self.artifactRoot.appending(path: "research/ggml-base.bin")
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw XCTSkip("The pinned local model is required for the hashing performance test.")
        }

        let start = ContinuousClock.now
        let digest = try await ModelStore.sha256(of: modelURL)
        let elapsed = start.duration(to: .now).timeInterval

        XCTAssertEqual(digest, ModelManifest.recommended.sha256)
        XCTAssertLessThan(elapsed, 3, "Hashing the 148 MB model took \(elapsed) seconds")
    }

    func testShortTranscriptionCompletesWithinBudget() async throws {
        let modelURL = Self.artifactRoot.appending(path: "research/ggml-base.bin")
        let audioURL = Self.artifactRoot.appending(path: "fixtures/whisper-smoke-real.wav")
        guard FileManager.default.fileExists(atPath: modelURL.path),
              FileManager.default.fileExists(atPath: audioURL.path) else {
            throw XCTSkip("The pinned model and local speech fixture are required for the inference performance test.")
        }

        let start = ContinuousClock.now
        let decoder = AudioDecoder()
        let selection = try await decoder.inspect(audioURL)
        let samples = try await decoder.decode(selection) { _ in }
        let result = try await WhisperEngine().transcribe(
            samples: samples,
            modelURL: modelURL,
            language: .english,
            cancellation: TranscriptionCancellation(),
            progress: { _ in }
        )
        let elapsed = start.duration(to: .now).timeInterval

        XCTAssertFalse(result.text.isEmpty)
        XCTAssertLessThan(elapsed, 15, "A 3.1-second fixture took \(elapsed) seconds to transcribe")
    }

    private static let artifactRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: ".build-artifacts", directoryHint: .isDirectory)
    }()
}

private extension Duration {
    var timeInterval: TimeInterval {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1_000_000_000_000_000_000
    }
}
