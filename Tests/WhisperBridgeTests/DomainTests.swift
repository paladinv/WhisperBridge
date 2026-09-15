import CryptoKit
import XCTest
final class DomainTests: XCTestCase {
    func testFilePolicyAcceptsDocumentedBoundaries() throws {
        let url = URL(fileURLWithPath: "recording.wav")
        XCTAssertNoThrow(try FilePolicy.validate(
            url: url,
            byteCount: FilePolicy.maximumBytes,
            duration: FilePolicy.maximumDuration
        ))
    }

    func testFilePolicyRejectsOversizeAndUnsupportedInputs() {
        XCTAssertThrowsError(try FilePolicy.validate(
            url: URL(fileURLWithPath: "recording.wav"),
            byteCount: FilePolicy.maximumBytes + 1,
            duration: 10
        )) { XCTAssertEqual($0 as? AppFailure, .fileTooLarge) }

        XCTAssertThrowsError(try FilePolicy.validate(
            url: URL(fileURLWithPath: "notes.txt"),
            byteCount: 20,
            duration: 10
        )) { XCTAssertEqual($0 as? AppFailure, .unsupportedFormat) }
    }

    func testTranscriptTracksEditsWithoutChangingRawText() {
        var transcript = Transcript(rawText: "forty two", editedText: "forty two", detectedLanguage: "English")
        XCTAssertFalse(transcript.isDirty)
        transcript.editedText = "42"
        XCTAssertTrue(transcript.isDirty)
        XCTAssertEqual(transcript.rawText, "forty two")
    }

    func testCancellationFlagIsSafeToRepeat() {
        let flag = TranscriptionCancellation()
        XCTAssertFalse(flag.isCancelled)
        flag.cancel()
        flag.cancel()
        XCTAssertTrue(flag.isCancelled)
    }

    func testRecommendedModelManifestIsPinned() {
        let manifest = ModelManifest.recommended
        XCTAssertEqual(manifest.byteCount, 147_951_465)
        XCTAssertEqual(manifest.sha256.count, 64)
        XCTAssertEqual(manifest.downloadURL.scheme, "https")
    }

    func testModelStoreInstallsOnlyMatchingData() async throws {
        let directory = Self.artifactRoot.appending(path: "model-store", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
        let data = Data("verified-model".utf8)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let manifest = ModelManifest(
            filename: "test.bin",
            displayName: "Test",
            byteCount: Int64(data.count),
            sha256: digest,
            downloadURL: URL(string: "https://example.invalid/test.bin")!
        )
        let store = ModelStore(directory: directory, manifest: manifest)

        try await store.install(data)
        let installed = await store.isInstalled()
        XCTAssertTrue(installed)
        let modelURL = await store.modelURL
        XCTAssertEqual(try Data(contentsOf: modelURL), data)

        await XCTAssertThrowsErrorAsync {
            try await store.install(Data("wrong".utf8))
        }
    }

    static let artifactRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: ".build-artifacts/test-runtime", directoryHint: .isDirectory)
    }()
}

private extension XCTestCase {
    func XCTAssertThrowsErrorAsync(
        _ expression: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected an error", file: file, line: line)
        } catch {
            // Expected.
        }
    }
}
