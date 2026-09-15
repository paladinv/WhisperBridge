import Foundation
import Testing
import ZIPFoundation
@testable import WhisperBridgeCore

@Suite("Transcript core")
struct TranscriptCoreTests {
    @Test("decoder presets and advanced ranges validate")
    func decodingValidation() throws {
        #expect(DecodingPreset.fast.options.strategy == .greedy)
        #expect(DecodingPreset.accurate.options.beamSize == 5)
        #expect(throws: TranscriptCoreError.self) { try WhisperDecodingOptions(beamSize: 0).validated() }
        #expect(try TranscriptTimeRange(start: 1, end: 2).validated(duration: 3).end == 2)
        #expect(throws: TranscriptCoreError.self) { try TranscriptTimeRange(start: 2, end: 1).validated() }
    }

    @Test("subtitle formats round trip timing and Unicode")
    func subtitles() throws {
        let source = [TranscriptSegment(start: 1.25, end: 2.75, rawText: "Héllo 世界")]
        for format in [SubtitleFormat.srt, .vtt] {
            let decoded = try SubtitleCodec.parse(SubtitleCodec.serialize(source, format: format), format: format)
            #expect(decoded.count == 1)
            #expect(decoded[0].rawText == "Héllo 世界")
            #expect(abs(decoded[0].start - 1.25) < 0.001)
        }
    }

    @Test("speaker overlap, editing, fillers, compact mode, and range replacement")
    func editing() throws {
        let speaker = TranscriptSpeaker(name: "Ada")
        var document = TranscriptDocument(title: "Meeting", sourceFilename: "meeting.wav", duration: 5, modelID: "whisper-base-multilingual", speakers: [speaker], segments: [
            TranscriptSegment(start: 0, end: 2, rawText: "Um, hello"),
            TranscriptSegment(start: 2, end: 4, rawText: "world")
        ])
        let first = document.segments[0].id
        #expect(TranscriptEditing.speaker(for: document.segments[0], intervals: [(0.5, 1.5, speaker.id)]) == speaker.id)
        TranscriptEditing.assignSpeaker(speaker.id, to: [first], in: &document)
        document.segments[0].fillersHidden = true
        #expect(document.segments[0].displayText == "hello")
        #expect(TranscriptFormatting.renderedSegments(document, compact: true).hasPrefix("Ada: hello"))
        TranscriptEditing.delete([first], in: &document)
        #expect(!document.activeText.contains("hello"))
        TranscriptEditing.restore([first], in: &document)
        TranscriptEditing.replace(range: TranscriptTimeRange(start: 2, end: 4), with: [TranscriptSegment(start: 2, end: 3, rawText: "replacement")], in: &document)
        #expect(document.segments.map(\.displayText).contains("replacement"))
    }

    @Test("SQLite WAL library persists, deduplicates, filters speakers, and ranks FTS")
    func database() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: ".build-artifacts/core-store-test")
        try? FileManager.default.removeItem(at: root)
        let store = try TranscriptStore(directory: root)
        let audio = root.appending(path: "fixture.wav")
        try Data("audio".utf8).write(to: audio)
        let a = try store.importAudio(from: audio, duration: 2)
        let b = try store.importAudio(from: audio, duration: 2)
        #expect(a.id == b.id)
        let speaker = TranscriptSpeaker(name: "Grace")
        let document = TranscriptDocument(title: "Architecture", sourceFilename: "fixture.wav", audioAssetID: a.id, duration: 2, modelID: "test", speakers: [speaker], segments: [TranscriptSegment(start: 0, end: 2, speakerID: speaker.id, rawText: "distributed database design")])
        try store.save(document)
        #expect(try store.load(id: document.id)?.activeText == "distributed database design")
        #expect(try store.search("database").first?.transcriptID == document.id)
        #expect(try store.search("", speaker: "Grace").count == 1)
    }

    @Test("corrupt SQLite is preserved and replaced with a clean library")
    func databaseRecovery() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: ".build-artifacts/core-corrupt-store-test")
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not a sqlite database".utf8).write(to: root.appending(path: "library-v1.sqlite3"))
        let recovered = try TranscriptStore(directory: root)
        #expect(try recovered.list().isEmpty)
        let backups = try FileManager.default.contentsOfDirectory(at: root.appending(path: "library/recovery"), includingPropertiesForKeys: nil)
        #expect(backups.contains { $0.lastPathComponent.hasPrefix("corrupt-") })
    }

    @Test("TST v2 round trips rich data")
    func tstArchive() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: ".build-artifacts/tst-roundtrip-test")
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try TranscriptStore(directory: root.appending(path: "store"))
        let speaker = TranscriptSpeaker(name: "Speaker 1")
        let document = TranscriptDocument(title: "Project", sourceFilename: "audio.wav", duration: 3, modelID: "whisper-base-multilingual", speakers: [speaker], segments: [TranscriptSegment(start: 0, end: 3, speakerID: speaker.id, rawText: "Hello")], legacyMetadata: ["custom": "kept"])
        let archive = root.appending(path: "project.tst")
        try TSTArchiveService.exportProject(document, audioURL: nil, to: archive)
        let imported = try TSTArchiveService.importProject(from: archive, into: store)
        #expect(imported.activeText == "Hello")
        #expect(imported.legacyMetadata["custom"] == "kept")
        #expect(imported.speakers.first?.name == "Speaker 1")
    }

    @Test("TST import rejects traversal and malformed rich payloads without records")
    func tstArchiveValidation() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: ".build-artifacts/tst-invalid-test")
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try TranscriptStore(directory: root.appending(path: "store"))

        let traversal = root.appending(path: "traversal.tst")
        try makeArchive(traversal, entries: [
            "manifest.json": Data("{}".utf8), "transcript.txt": Data("safe".utf8), "../escape.txt": Data("no".utf8)
        ])
        #expect(throws: TranscriptCoreError.self) { try TSTArchiveService.importProject(from: traversal, into: store) }

        let corrupt = root.appending(path: "corrupt.tst")
        try makeArchive(corrupt, entries: [
            "manifest.json": Data("{}".utf8), "transcript.txt": Data("safe".utf8), "segments.json": Data("{\"invalid\":true}".utf8)
        ])
        #expect(throws: TranscriptCoreError.self) { try TSTArchiveService.importProject(from: corrupt, into: store) }
        #expect(try store.list().isEmpty)
    }

    @Test("custom export placeholders use structured presentation")
    func templates() {
        let document = TranscriptDocument(title: "Test", sourceFilename: "test.wav", duration: 1, detectedLanguage: "en", modelID: "test", segments: [TranscriptSegment(start: 0, end: 1, rawText: "Hello")])
        let rendered = TranscriptExportRenderer.render(template: "{{language}}|{{segment_count}}|{{transcript}}", document: document)
        #expect(rendered == "en|1|Hello")
    }

    @Test("CSV round trips quoted text and speaker labels")
    func csv() throws {
        let speaker = TranscriptSpeaker(name: "Doe, Jane")
        let source = TranscriptDocument(title: "CSV", sourceFilename: "audio.wav", duration: 2, modelID: "test", speakers: [speaker], segments: [
            TranscriptSegment(start: 0.25, end: 2, speakerID: speaker.id, rawText: "She said \"hello\".\nNext line.")
        ])
        let parsed = try CSVTranscriptCodec.parse(CSVTranscriptCodec.serialize(source), title: "CSV", sourceFilename: "file.csv")
        #expect(parsed.segments.first?.rawText == "She said \"hello\".\nNext line.")
        #expect(parsed.speakers.first?.name == "Doe, Jane")
    }

    private func makeArchive(_ url: URL, entries: [String: Data]) throws {
        let archive = try Archive(url: url, accessMode: .create)
        for (path, data) in entries {
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .none) { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            }
        }
    }
}
