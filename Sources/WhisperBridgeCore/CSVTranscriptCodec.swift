import Foundation

public enum CSVTranscriptCodec {
    public static func serialize(_ document: TranscriptDocument) -> String {
        let names = Dictionary(uniqueKeysWithValues: document.speakers.map { ($0.id, $0.name) })
        let rows = document.segments.filter { !$0.isDeleted }.map { segment in
            [String(segment.start), String(segment.end), segment.speakerID.flatMap { names[$0] } ?? "", segment.displayText]
                .map(escape).joined(separator: ",")
        }
        return (["start,end,speaker,text"] + rows).joined(separator: "\n") + "\n"
    }

    public static func parse(_ source: String, title: String, sourceFilename: String) throws -> TranscriptDocument {
        let rows = try rows(in: source)
        guard let header = rows.first?.map({ $0.lowercased() }), header == ["start", "end", "speaker", "text"] else {
            throw TranscriptCoreError.invalidSetting("CSV transcripts require start,end,speaker,text columns.")
        }
        var speakersByName: [String: TranscriptSpeaker] = [:]
        var segments: [TranscriptSegment] = []
        for row in rows.dropFirst() where !row.allSatisfy({ $0.isEmpty }) {
            guard row.count == 4, let start = Double(row[0]), let end = Double(row[1]), start >= 0, end >= start else {
                throw TranscriptCoreError.invalidSetting("A CSV transcript row has invalid timing or columns.")
            }
            let speakerID: UUID?
            if row[2].isEmpty {
                speakerID = nil
            } else {
                let speaker = speakersByName[row[2]] ?? TranscriptSpeaker(name: row[2], colorIndex: speakersByName.count)
                speakersByName[row[2]] = speaker
                speakerID = speaker.id
            }
            segments.append(TranscriptSegment(start: start, end: end, speakerID: speakerID, rawText: row[3]))
        }
        return TranscriptDocument(
            title: title,
            sourceFilename: sourceFilename,
            duration: segments.map(\.end).max() ?? 0,
            modelID: "csv-import",
            speakers: speakersByName.values.sorted { $0.colorIndex < $1.colorIndex },
            segments: segments
        )
    }

    private static func escape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func rows(in source: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var index = source.startIndex
        while index < source.endIndex {
            let character = source[index]
            if quoted {
                if character == "\"" {
                    let next = source.index(after: index)
                    if next < source.endIndex, source[next] == "\"" { field.append("\""); index = next }
                    else { quoted = false }
                } else { field.append(character) }
            } else {
                switch character {
                case "\"" where field.isEmpty: quoted = true
                case ",": row.append(field); field = ""
                case "\n": row.append(field); rows.append(row); row = []; field = ""
                case "\r": break
                default: field.append(character)
                }
            }
            index = source.index(after: index)
        }
        guard !quoted else { throw TranscriptCoreError.invalidSetting("CSV transcript contains an unterminated quoted value.") }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}
