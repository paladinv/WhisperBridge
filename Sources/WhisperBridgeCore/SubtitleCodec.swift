import Foundation

public enum SubtitleFormat: String, Sendable { case srt, vtt }

public enum SubtitleCodec {
    public static func parse(_ text: String, format: SubtitleFormat) throws -> [TranscriptSegment] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var segments: [TranscriptSegment] = []
        for block in blocks {
            var lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "WEBVTT" { lines.removeFirst() }
            if lines.first?.allSatisfy(\.isNumber) == true { lines.removeFirst() }
            guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let sides = lines[timingIndex].components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
            guard sides.count == 2 else { throw TranscriptCoreError.invalidArchive("A subtitle time range is malformed.") }
            let start = try parseTimestamp(sides[0])
            let endToken = sides[1].split(separator: " ").first.map(String.init) ?? sides[1]
            let end = try parseTimestamp(endToken)
            let content = lines.dropFirst(timingIndex + 1).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { segments.append(TranscriptSegment(start: start, end: end, rawText: content)) }
        }
        return segments
    }

    public static func serialize(_ segments: [TranscriptSegment], format: SubtitleFormat) -> String {
        let active = segments.filter { !$0.isDeleted }
        let body = active.enumerated().map { index, segment in
            let decimal: Character = format == .srt ? "," : "."
            let number = format == .srt ? "\(index + 1)\n" : ""
            return "\(number)\(TranscriptFormatting.timestamp(segment.start, decimal: decimal)) --> \(TranscriptFormatting.timestamp(segment.end, decimal: decimal))\n\(segment.displayText)"
        }.joined(separator: "\n\n")
        return format == .vtt ? "WEBVTT\n\n\(body)\n" : "\(body)\n"
    }

    public static func parseTimestamp(_ value: String) throws -> Double {
        let fields = value.replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard fields.count == 3, let hours = Double(fields[0]), let minutes = Double(fields[1]), let seconds = Double(fields[2]),
              minutes < 60, seconds < 60 else { throw TranscriptCoreError.invalidArchive("A subtitle timestamp is invalid.") }
        return hours * 3_600 + minutes * 60 + seconds
    }
}

public enum TranscriptExportRenderer {
    public static func render(template: String, document: TranscriptDocument, compact: Bool = false) -> String {
        let segments = TranscriptFormatting.renderedSegments(document, compact: compact)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let segmentJSON = (try? encoder.encode(document.segments)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let replacements = [
            "{{transcript}}": document.activeText,
            "{{language}}": document.detectedLanguage ?? "",
            "{{segment_count}}": String(document.segments.filter { !$0.isDeleted }.count),
            "{{segments}}": segments,
            "{{segments_json}}": segmentJSON,
        ]
        return replacements.reduce(template) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }
}
