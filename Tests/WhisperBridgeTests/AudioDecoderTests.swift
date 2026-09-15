@preconcurrency import AVFoundation
import XCTest
final class AudioDecoderTests: XCTestCase {
    func testDecodesWaveToWhisperSampleRate() async throws {
        let url = Self.artifactRoot.appending(path: "decoder-tone.wav")
        try FileManager.default.createDirectory(at: Self.artifactRoot, withIntermediateDirectories: true)
        try Self.writeTone(to: url, sampleRate: 44_100, seconds: 1)

        let decoder = AudioDecoder()
        let selection = try await decoder.inspect(url)
        let samples = try await decoder.decode(selection) { _ in }

        XCTAssertEqual(selection.duration, 1, accuracy: 0.02)
        XCTAssertEqual(samples.count, 16_000, accuracy: 100)
        XCTAssertGreaterThan(samples.map(abs).max() ?? 0, 0.05)
    }

    func testRejectsFileWithAudioExtensionButInvalidContents() async throws {
        let url = Self.artifactRoot.appending(path: "invalid.mp3")
        try FileManager.default.createDirectory(at: Self.artifactRoot, withIntermediateDirectories: true)
        try Data("not audio".utf8).write(to: url)

        do {
            _ = try await AudioDecoder().inspect(url)
            XCTFail("Invalid audio should not be accepted")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    private static func writeTone(to url: URL, sampleRate: Double, seconds: Double) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let frameCount = AVAudioFrameCount(sampleRate * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData![0]
        let angularFrequency = 2.0 * Double.pi * 440.0
        for frame in 0..<Int(frameCount) {
            let phase = angularFrequency * Double(frame) / sampleRate
            channel[frame] = Float(0.2 * sin(phase))
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    static let artifactRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: ".build-artifacts/test-runtime", directoryHint: .isDirectory)
    }()
}
