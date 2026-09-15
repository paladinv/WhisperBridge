import Foundation
import ZIPFoundation

public struct TSTProjectManifest: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var audioFilename: String?
    public var transcriptFilename: String?
    public var metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case formatVersion = "format_version"
        case audioFilename = "audio_filename"
        case transcriptFilename = "transcript_filename"
        case metadata
    }

    public init(formatVersion: Int = 2, audioFilename: String?, transcriptFilename: String? = nil, metadata: [String: String] = [:]) {
        self.formatVersion = formatVersion
        self.audioFilename = audioFilename
        self.transcriptFilename = transcriptFilename
        self.metadata = metadata
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try values.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        audioFilename = try values.decodeIfPresent(String.self, forKey: .audioFilename)
        transcriptFilename = try values.decodeIfPresent(String.self, forKey: .transcriptFilename)
        if let strings = try? values.decode([String: String].self, forKey: .metadata) {
            metadata = strings
        } else if let loose = try? values.decode([String: LooseJSON].self, forKey: .metadata) {
            metadata = loose.mapValues(\.description)
        } else {
            metadata = [:]
        }
    }
}

private enum LooseJSON: Codable, CustomStringConvertible {
    case string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let item = try? value.decode(String.self) { self = .string(item) }
        else if let item = try? value.decode(Bool.self) { self = .bool(item) }
        else { self = .number(try value.decode(Double.self)) }
    }
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self { case .string(let item): try value.encode(item); case .number(let item): try value.encode(item); case .bool(let item): try value.encode(item); case .null: try value.encodeNil() }
    }
    var description: String { switch self { case .string(let value): value; case .number(let value): String(value); case .bool(let value): String(value); case .null: "null" } }
}

private struct TSTStructuredPayload: Codable {
    let speakers: [TranscriptSpeaker]
    let segments: [TranscriptSegment]
    let timestampGranularity: TimestampGranularity
    let decodingOptions: WhisperDecodingOptions
    let modelID: String
    let modelRevision: String
    let detectedLanguage: String?
    let duration: Double
    let sourceRange: TranscriptTimeRange?
}

public enum TSTArchiveService {
    private static let maximumEntries = 64
    private static let maximumEntryBytes: UInt64 = 550 * 1_048_576
    private static let maximumExpandedBytes: UInt64 = 600 * 1_048_576

    public static func importProject(from source: URL, into store: TranscriptStore) throws -> TranscriptDocument {
        let archive: Archive
        do { archive = try Archive(url: source, accessMode: .read) }
        catch { throw TranscriptCoreError.invalidArchive("The ZIP container cannot be opened.") }
        let entries = Array(archive)
        try validate(entries)
        guard let manifestEntry = entries.first(where: { $0.path == "manifest.json" }),
              let transcriptEntry = entries.first(where: { $0.path == "transcript.txt" }) else {
            throw TranscriptCoreError.invalidArchive("manifest.json and transcript.txt are required.")
        }
        let decoder = JSONDecoder()
        let manifest: TSTProjectManifest
        do {
            manifest = try decoder.decode(TSTProjectManifest.self, from: try data(from: manifestEntry, archive: archive, limit: 1_048_576))
        } catch {
            throw TranscriptCoreError.invalidArchive("manifest.json is not a supported STTTTS manifest.")
        }
        let transcriptText = String(data: try data(from: transcriptEntry, archive: archive, limit: 64 * 1_048_576), encoding: .utf8)
        guard let transcriptText else { throw TranscriptCoreError.invalidArchive("transcript.txt is not UTF-8 text.") }
        let structured: TSTStructuredPayload?
        if let structuredEntry = entries.first(where: { $0.path == "segments.json" }) {
            do {
                structured = try decoder.decode(TSTStructuredPayload.self, from: data(from: structuredEntry, archive: archive, limit: 64 * 1_048_576))
            } catch {
                throw TranscriptCoreError.invalidArchive("segments.json is present but invalid.")
            }
        } else {
            structured = nil
        }
        var legacyMetadata = manifest.metadata
        if let transcriptFilename = manifest.transcriptFilename {
            legacyMetadata["stttts_transcript_filename"] = transcriptFilename
        }
        let title = source.deletingPathExtension().lastPathComponent
        var document = TranscriptDocument(
            title: title, sourceFilename: manifest.audioFilename ?? title,
            duration: structured?.duration ?? Double(manifest.metadata["duration"] ?? "") ?? 0,
            detectedLanguage: structured?.detectedLanguage ?? manifest.metadata["language"],
            modelID: structured?.modelID ?? manifest.metadata["model"] ?? "legacy-stttts",
            modelRevision: structured?.modelRevision ?? "bbb51c5",
            sourceRange: structured?.sourceRange,
            timestampGranularity: structured?.timestampGranularity ?? .segment,
            decodingOptions: structured?.decodingOptions ?? DecodingPreset.balanced.options,
            speakers: structured?.speakers ?? [],
            segments: structured?.segments ?? [TranscriptSegment(start: 0, end: structured?.duration ?? 0, rawText: transcriptText)],
            legacyMetadata: legacyMetadata
        )
        if let audioFilename = manifest.audioFilename,
           let audioEntry = entries.first(where: { $0.path == "media/\(audioFilename)" }) {
            let stagingDirectory = store.directory.appending(path: "library/import-staging", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let staged = stagingDirectory.appending(path: "\(UUID().uuidString)-\(URL(fileURLWithPath: audioFilename).lastPathComponent)")
            defer { try? FileManager.default.removeItem(at: staged) }
            _ = try archive.extract(audioEntry, to: staged)
            let asset = try store.importAudio(from: staged, duration: document.duration)
            document.audioAssetID = asset.id
        }
        try store.save(document)
        return document
    }

    public static func exportProject(_ document: TranscriptDocument, audioURL: URL?, to destination: URL) throws {
        let temporary = destination.deletingLastPathComponent().appending(path: ".\(destination.lastPathComponent).partial-\(UUID().uuidString)")
        try? FileManager.default.removeItem(at: temporary)
        let archive: Archive
        do { archive = try Archive(url: temporary, accessMode: .create) }
        catch { throw TranscriptCoreError.invalidArchive("The destination archive cannot be created.") }
        do {
            var exportedMetadata = document.legacyMetadata
            let transcriptFilename = exportedMetadata.removeValue(forKey: "stttts_transcript_filename")
            let manifest = TSTProjectManifest(audioFilename: audioURL?.lastPathComponent, transcriptFilename: transcriptFilename, metadata: exportedMetadata.merging([
                "duration": String(document.duration), "language": document.detectedLanguage ?? "", "model": document.modelID
            ]) { _, current in current })
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try add(try encoder.encode(manifest), path: "manifest.json", to: archive)
            try add(Data(document.activeText.utf8), path: "transcript.txt", to: archive)
            let payload = TSTStructuredPayload(speakers: document.speakers, segments: document.segments, timestampGranularity: document.timestampGranularity, decodingOptions: document.decodingOptions, modelID: document.modelID, modelRevision: document.modelRevision, detectedLanguage: document.detectedLanguage, duration: document.duration, sourceRange: document.sourceRange)
            try add(try encoder.encode(payload), path: "segments.json", to: archive)
            if let audioURL { try archive.addEntry(with: "media/\(audioURL.lastPathComponent)", fileURL: audioURL, compressionMethod: .none) }
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private static func validate(_ entries: [Entry]) throws {
        guard entries.count <= maximumEntries else { throw TranscriptCoreError.invalidArchive("The archive contains too many entries.") }
        var paths = Set<String>()
        var expanded: UInt64 = 0
        for entry in entries {
            guard entry.type == .file else { throw TranscriptCoreError.invalidArchive("Directories and symbolic links are not accepted as entries.") }
            let path = entry.path
            guard !path.hasPrefix("/"), !path.contains("\\"), !path.split(separator: "/").contains("..") else { throw TranscriptCoreError.invalidArchive("An entry escapes the project directory.") }
            guard paths.insert(path).inserted else { throw TranscriptCoreError.invalidArchive("The archive contains duplicate paths.") }
            guard entry.uncompressedSize <= maximumEntryBytes else { throw TranscriptCoreError.invalidArchive("An entry is too large.") }
            expanded += entry.uncompressedSize
            guard expanded <= maximumExpandedBytes else { throw TranscriptCoreError.invalidArchive("The expanded project is too large.") }
            if entry.compressedSize > 0 && entry.uncompressedSize / entry.compressedSize > 200 { throw TranscriptCoreError.invalidArchive("An entry has an unsafe compression ratio.") }
        }
    }

    private static func data(from entry: Entry, archive: Archive, limit: UInt64) throws -> Data {
        guard entry.uncompressedSize <= limit else { throw TranscriptCoreError.invalidArchive("A text entry is too large.") }
        var output = Data()
        _ = try archive.extract(entry) { chunk in output.append(chunk) }
        return output
    }

    private static func add(_ data: Data, path: String, to archive: Archive) throws {
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate) { (position: Int64, size: Int) in
            let start = Int(position)
            return data.subdata(in: start..<start + size)
        }
    }
}
