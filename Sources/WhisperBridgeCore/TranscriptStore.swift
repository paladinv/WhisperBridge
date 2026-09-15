import CryptoKit
import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class TranscriptStore: @unchecked Sendable {
    public static func defaultDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment["WHISPERBRIDGE_DATA_DIR"] { return URL(fileURLWithPath: override, isDirectory: true) }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "LM Studio/WhisperBridge", directoryHint: .isDirectory)
    }

    public let directory: URL
    public let databaseURL: URL
    private let lock = NSRecursiveLock()
    private var database: OpaquePointer?

    public init(directory: URL = TranscriptStore.defaultDirectory()) throws {
        self.directory = directory
        databaseURL = directory.appending(path: "library-v1.sqlite3")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let databaseExisted = FileManager.default.fileExists(atPath: databaseURL.path)
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw TranscriptCoreError.database("The SQLite file could not be opened.")
        }
        if databaseExisted {
            do {
                guard try query("PRAGMA integrity_check").first?.string(0) == "ok" else { throw TranscriptCoreError.database("SQLite integrity check failed.") }
            } catch {
                try recoverCorruptDatabase()
            }
        }
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA foreign_keys=ON")
        try execute("PRAGMA busy_timeout=5000")
        try migrate()
    }

    deinit { sqlite3_close(database) }

    public func save(_ document: TranscriptDocument) throws {
        lock.lock(); defer { lock.unlock() }
        try execute("BEGIN IMMEDIATE")
        do {
            let metadata = try json(document.legacyMetadata)
            let options = try json(document.decodingOptions)
            try run(
                """
                INSERT INTO transcripts(id,title,source_filename,audio_asset_id,duration,detected_language,model_id,model_revision,
                source_start,source_end,timestamp_granularity,decoding_json,created_at,updated_at,legacy_metadata_json)
                VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(id) DO UPDATE SET title=excluded.title,source_filename=excluded.source_filename,
                audio_asset_id=excluded.audio_asset_id,duration=excluded.duration,detected_language=excluded.detected_language,
                model_id=excluded.model_id,model_revision=excluded.model_revision,source_start=excluded.source_start,
                source_end=excluded.source_end,timestamp_granularity=excluded.timestamp_granularity,
                decoding_json=excluded.decoding_json,updated_at=excluded.updated_at,legacy_metadata_json=excluded.legacy_metadata_json
                """,
                [.text(document.id.uuidString), .text(document.title), .text(document.sourceFilename), .optionalText(document.audioAssetID),
                 .double(document.duration), .optionalText(document.detectedLanguage), .text(document.modelID), .text(document.modelRevision),
                 .optionalDouble(document.sourceRange?.start), .optionalDouble(document.sourceRange?.end), .text(document.timestampGranularity.rawValue),
                 .text(options), .double(document.createdAt.timeIntervalSince1970), .double(document.updatedAt.timeIntervalSince1970), .text(metadata)]
            )
            try run("DELETE FROM speakers WHERE transcript_id=?", [.text(document.id.uuidString)])
            try run("DELETE FROM segments WHERE transcript_id=?", [.text(document.id.uuidString)])
            try run("DELETE FROM transcript_fts WHERE transcript_id=?", [.text(document.id.uuidString)])
            for (index, speaker) in document.speakers.enumerated() {
                try run("INSERT INTO speakers(id,transcript_id,name,color_index,ordinal) VALUES(?,?,?,?,?)",
                        [.text(speaker.id.uuidString), .text(document.id.uuidString), .text(speaker.name), .int(speaker.colorIndex), .int(index)])
            }
            let speakerNames = Dictionary(uniqueKeysWithValues: document.speakers.map { ($0.id, $0.name) })
            for (index, segment) in document.segments.enumerated() {
                try run(
                    "INSERT INTO segments(id,transcript_id,ordinal,start_time,end_time,speaker_id,raw_text,edited_text,is_deleted,fillers_hidden,overlap,timing_approximate) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                    [.text(segment.id.uuidString), .text(document.id.uuidString), .int(index), .double(segment.start), .double(segment.end),
                     .optionalText(segment.speakerID?.uuidString), .text(segment.rawText), .text(segment.editedText), .bool(segment.isDeleted),
                     .bool(segment.fillersHidden), .bool(segment.hasOverlappingSpeech), .bool(segment.timingIsApproximate)]
                )
                for (wordIndex, word) in segment.words.enumerated() {
                    try run("INSERT INTO words(id,segment_id,ordinal,start_time,end_time,raw_text,is_filler) VALUES(?,?,?,?,?,?,?)",
                            [.text(word.id.uuidString), .text(segment.id.uuidString), .int(wordIndex), .optionalDouble(word.start),
                             .optionalDouble(word.end), .text(word.rawText), .bool(word.isFiller)])
                }
                if !segment.isDeleted {
                    try run("INSERT INTO transcript_fts(transcript_id,segment_id,title,text,speaker) VALUES(?,?,?,?,?)",
                            [.text(document.id.uuidString), .text(segment.id.uuidString), .text(document.title), .text(segment.displayText),
                             .text(segment.speakerID.flatMap { speakerNames[$0] } ?? "")])
                }
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    public func load(id: UUID) throws -> TranscriptDocument? {
        lock.lock(); defer { lock.unlock() }
        let rows = try query("SELECT title,source_filename,audio_asset_id,duration,detected_language,model_id,model_revision,source_start,source_end,timestamp_granularity,decoding_json,created_at,updated_at,legacy_metadata_json FROM transcripts WHERE id=?", [.text(id.uuidString)])
        guard let row = rows.first else { return nil }
        let speakers = try query("SELECT id,name,color_index FROM speakers WHERE transcript_id=? ORDER BY ordinal", [.text(id.uuidString)]).compactMap { item -> TranscriptSpeaker? in
            guard let uuid = UUID(uuidString: item.string(0)) else { return nil }
            return TranscriptSpeaker(id: uuid, name: item.string(1), colorIndex: item.int(2))
        }
        let segments = try query("SELECT id,start_time,end_time,speaker_id,raw_text,edited_text,is_deleted,fillers_hidden,overlap,timing_approximate FROM segments WHERE transcript_id=? ORDER BY ordinal", [.text(id.uuidString)]).compactMap { item -> TranscriptSegment? in
            guard let segmentID = UUID(uuidString: item.string(0)) else { return nil }
            let words = (try? query("SELECT id,start_time,end_time,raw_text,is_filler FROM words WHERE segment_id=? ORDER BY ordinal", [.text(segmentID.uuidString)]))?.compactMap { word -> TranscriptWord? in
                guard let wordID = UUID(uuidString: word.string(0)) else { return nil }
                return TranscriptWord(id: wordID, start: word.optionalDouble(1), end: word.optionalDouble(2), rawText: word.string(3), isFiller: word.bool(4))
            } ?? []
            return TranscriptSegment(id: segmentID, start: item.double(1), end: item.double(2), speakerID: UUID(uuidString: item.optionalString(3) ?? ""), rawText: item.string(4), editedText: item.string(5), words: words, isDeleted: item.bool(6), fillersHidden: item.bool(7), hasOverlappingSpeech: item.bool(8), timingIsApproximate: item.bool(9))
        }
        let options = (try? decode(WhisperDecodingOptions.self, row.string(10))) ?? DecodingPreset.balanced.options
        let metadata = (try? decode([String: String].self, row.string(13))) ?? [:]
        let sourceRange = row.optionalDouble(7).flatMap { start in row.optionalDouble(8).map { TranscriptTimeRange(start: start, end: $0) } }
        return TranscriptDocument(id: id, title: row.string(0), sourceFilename: row.string(1), audioAssetID: row.optionalString(2), duration: row.double(3), detectedLanguage: row.optionalString(4), modelID: row.string(5), modelRevision: row.string(6), sourceRange: sourceRange, timestampGranularity: TimestampGranularity(rawValue: row.string(9)) ?? .segment, decodingOptions: options, speakers: speakers, segments: segments, createdAt: Date(timeIntervalSince1970: row.double(11)), updatedAt: Date(timeIntervalSince1970: row.double(12)), legacyMetadata: metadata)
    }

    public func list(limit: Int = 200, offset: Int = 0) throws -> [TranscriptSummary] {
        lock.lock(); defer { lock.unlock() }
        return try query("SELECT id,title,source_filename,duration,updated_at FROM transcripts ORDER BY updated_at DESC LIMIT ? OFFSET ?", [.int(max(1, min(limit, 500))), .int(max(0, offset))]).compactMap { row in
            guard let id = UUID(uuidString: row.string(0)) else { return nil }
            let names = (try? query("SELECT name FROM speakers WHERE transcript_id=? ORDER BY ordinal", [.text(id.uuidString)]).map { $0.string(0) }) ?? []
            return TranscriptSummary(id: id, title: row.string(1), sourceFilename: row.string(2), duration: row.double(3), updatedAt: Date(timeIntervalSince1970: row.double(4)), speakerNames: names)
        }
    }

    public func search(_ queryText: String, speaker: String? = nil, limit: Int = 50) throws -> [TranscriptSearchResult] {
        lock.lock(); defer { lock.unlock() }
        let terms = queryText.split(whereSeparator: \.isWhitespace).map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: " AND ")
        guard !terms.isEmpty || !(speaker?.isEmpty ?? true) else { return [] }
        let match = terms.isEmpty ? "speaker:\"\((speaker ?? "").replacingOccurrences(of: "\"", with: "\"\""))\"" : terms + (speaker.map { " AND speaker:\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" } ?? "")
        let sql = """
        SELECT f.transcript_id,f.segment_id,t.title,s.name,
        snippet(transcript_fts,3,'‹','›','…',18),g.start_time,bm25(transcript_fts)
        FROM transcript_fts f JOIN transcripts t ON t.id=f.transcript_id
        JOIN segments g ON g.id=f.segment_id LEFT JOIN speakers s ON s.id=g.speaker_id
        WHERE transcript_fts MATCH ? ORDER BY bm25(transcript_fts),t.updated_at DESC LIMIT ?
        """
        return try query(sql, [.text(match), .int(max(1, min(limit, 200)))]).compactMap { row in
            guard let transcriptID = UUID(uuidString: row.string(0)), let segmentID = UUID(uuidString: row.string(1)) else { return nil }
            return TranscriptSearchResult(transcriptID: transcriptID, segmentID: segmentID, title: row.string(2), speakerName: row.optionalString(3), snippet: row.string(4), start: row.double(5), rank: row.double(6))
        }
    }

    public func delete(id: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        try execute("BEGIN IMMEDIATE")
        do {
            try run("DELETE FROM transcripts WHERE id=?", [.text(id.uuidString)])
            try run("DELETE FROM transcript_fts WHERE transcript_id=?", [.text(id.uuidString)])
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    public func importAudio(from source: URL, duration: Double) throws -> (id: String, url: URL) {
        lock.lock(); defer { lock.unlock() }
        let assetDirectory = directory.appending(path: "library/audio", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: assetDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let digest = try sha256(source)
        let ext = source.pathExtension.lowercased()
        let filename = ext.isEmpty ? digest : "\(digest).\(ext)"
        let destination = assetDirectory.appending(path: filename)
        if !FileManager.default.fileExists(atPath: destination.path) {
            let values = try source.resourceValues(forKeys: [.fileSizeKey])
            let required = Int64(values.fileSize ?? 0)
            let resourceCapacity = try assetDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
            let attributesCapacity = (try? FileManager.default.attributesOfFileSystem(forPath: assetDirectory.path)[.systemFreeSize] as? NSNumber)?.int64Value
            let capacity = resourceCapacity.volumeAvailableCapacityForImportantUsage
                ?? resourceCapacity.volumeAvailableCapacity.map(Int64.init)
                ?? attributesCapacity
            if let capacity, capacity > 0, capacity < required + 64 * 1_048_576 {
                throw TranscriptCoreError.audioCopy("There is not enough free disk space.")
            }
            let partial = assetDirectory.appending(path: ".\(filename).partial-\(UUID().uuidString)")
            do {
                try FileManager.default.copyItem(at: source, to: partial)
                guard try sha256(partial) == digest else { throw TranscriptCoreError.audioCopy("The copied file failed verification.") }
                try FileManager.default.moveItem(at: partial, to: destination)
            } catch {
                try? FileManager.default.removeItem(at: partial)
                throw error
            }
        }
        let size = (try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        try run("INSERT INTO audio_assets(id,sha256,relative_path,original_name,size_bytes,duration) VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET original_name=excluded.original_name",
                [.text(digest), .text(digest), .text("library/audio/\(filename)"), .text(source.lastPathComponent), .int64(size), .double(duration)])
        return (digest, destination)
    }

    public func audioURL(assetID: String) throws -> URL? {
        try query("SELECT relative_path FROM audio_assets WHERE id=?", [.text(assetID)]).first.map { directory.appending(path: $0.string(0)) }
    }

    private func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS audio_assets(id TEXT PRIMARY KEY,sha256 TEXT UNIQUE NOT NULL,relative_path TEXT NOT NULL,original_name TEXT NOT NULL,size_bytes INTEGER NOT NULL,duration REAL NOT NULL);
        CREATE TABLE IF NOT EXISTS transcripts(id TEXT PRIMARY KEY,title TEXT NOT NULL,source_filename TEXT NOT NULL,audio_asset_id TEXT REFERENCES audio_assets(id),duration REAL NOT NULL,detected_language TEXT,model_id TEXT NOT NULL,model_revision TEXT NOT NULL,source_start REAL,source_end REAL,timestamp_granularity TEXT NOT NULL,decoding_json TEXT NOT NULL,created_at REAL NOT NULL,updated_at REAL NOT NULL,legacy_metadata_json TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS speakers(id TEXT PRIMARY KEY,transcript_id TEXT NOT NULL REFERENCES transcripts(id) ON DELETE CASCADE,name TEXT NOT NULL,color_index INTEGER NOT NULL,ordinal INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS segments(id TEXT PRIMARY KEY,transcript_id TEXT NOT NULL REFERENCES transcripts(id) ON DELETE CASCADE,ordinal INTEGER NOT NULL,start_time REAL NOT NULL,end_time REAL NOT NULL,speaker_id TEXT REFERENCES speakers(id) ON DELETE SET NULL,raw_text TEXT NOT NULL,edited_text TEXT NOT NULL,is_deleted INTEGER NOT NULL,fillers_hidden INTEGER NOT NULL,overlap INTEGER NOT NULL,timing_approximate INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS words(id TEXT PRIMARY KEY,segment_id TEXT NOT NULL REFERENCES segments(id) ON DELETE CASCADE,ordinal INTEGER NOT NULL,start_time REAL,end_time REAL,raw_text TEXT NOT NULL,is_filler INTEGER NOT NULL);
        CREATE VIRTUAL TABLE IF NOT EXISTS transcript_fts USING fts5(transcript_id UNINDEXED,segment_id UNINDEXED,title,text,speaker,tokenize='unicode61 remove_diacritics 2',prefix='2 3 4');
        PRAGMA user_version=1;
        """)
    }

    private func recoverCorruptDatabase() throws {
        sqlite3_close(database)
        database = nil
        let recoveryDirectory = directory.appending(path: "library/recovery", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let recoveryID = "corrupt-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)"
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: databaseURL.path + suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.moveItem(at: source, to: recoveryDirectory.appending(path: recoveryID + suffix))
        }
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw TranscriptCoreError.database("A clean SQLite library could not be created after preserving the corrupt file.")
        }
    }

    private enum Value {
        case text(String), optionalText(String?), double(Double), optionalDouble(Double?), int(Int), int64(Int64), bool(Bool)
    }

    private struct Row {
        let values: [Any?]
        func string(_ index: Int) -> String { values[index] as? String ?? "" }
        func optionalString(_ index: Int) -> String? { values[index] as? String }
        func double(_ index: Int) -> Double { values[index] as? Double ?? 0 }
        func optionalDouble(_ index: Int) -> Double? { values[index] as? Double }
        func int(_ index: Int) -> Int { Int(values[index] as? Int64 ?? 0) }
        func bool(_ index: Int) -> Bool { (values[index] as? Int64 ?? 0) != 0 }
    }

    private func execute(_ sql: String) throws {
        lock.lock(); defer { lock.unlock() }
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "SQLite operation failed."
            sqlite3_free(error)
            throw TranscriptCoreError.database(message)
        }
    }

    private func run(_ sql: String, _ values: [Value] = []) throws {
        _ = try query(sql, values)
    }

    private func query(_ sql: String, _ values: [Value] = []) throws -> [Row] {
        lock.lock(); defer { lock.unlock() }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { throw dbError() }
        defer { sqlite3_finalize(statement) }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case .text(let item): sqlite3_bind_text(statement, index, item, -1, SQLITE_TRANSIENT)
            case .optionalText(let item):
                if let item { sqlite3_bind_text(statement, index, item, -1, SQLITE_TRANSIENT) }
                else { sqlite3_bind_null(statement, index) }
            case .double(let item): sqlite3_bind_double(statement, index, item)
            case .optionalDouble(let item):
                if let item { sqlite3_bind_double(statement, index, item) }
                else { sqlite3_bind_null(statement, index) }
            case .int(let item): sqlite3_bind_int64(statement, index, Int64(item))
            case .int64(let item): sqlite3_bind_int64(statement, index, item)
            case .bool(let item): sqlite3_bind_int(statement, index, item ? 1 : 0)
            }
        }
        var rows: [Row] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { break }
            guard result == SQLITE_ROW else { throw dbError() }
            var columns: [Any?] = []
            for column in 0..<sqlite3_column_count(statement) {
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER: columns.append(sqlite3_column_int64(statement, column))
                case SQLITE_FLOAT: columns.append(sqlite3_column_double(statement, column))
                case SQLITE_TEXT: columns.append(sqlite3_column_text(statement, column).map { String(cString: $0) })
                default: columns.append(nil)
                }
            }
            rows.append(Row(values: columns))
        }
        return rows
    }

    private func dbError() -> TranscriptCoreError { .database(database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite operation failed.") }
    private func json<T: Encodable>(_ value: T) throws -> String { String(data: try JSONEncoder().encode(value), encoding: .utf8)! }
    private func decode<T: Decodable>(_ type: T.Type, _ value: String) throws -> T { try JSONDecoder().decode(type, from: Data(value.utf8)) }

    private func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
