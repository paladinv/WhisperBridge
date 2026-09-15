import XCTest
final class WhisperSmokeTests: XCTestCase {
    func testPinnedWhisperModelTranscribesLocalSpeechFixture() async throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let modelURL = root.appending(path: ".build-artifacts/research/ggml-base.bin")
        let audioURL = root.appending(path: ".build-artifacts/fixtures/whisper-smoke-real.wav")
        guard FileManager.default.fileExists(atPath: modelURL.path),
              FileManager.default.fileExists(atPath: audioURL.path) else {
            throw XCTSkip("Local model and speech fixture are required for the real-engine smoke test.")
        }

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

        XCTAssertFalse(result.text.isEmpty)
        XCTAssertTrue(result.text.localizedCaseInsensitiveContains("audio"), "Actual transcript: \(result.text)")
    }
}
