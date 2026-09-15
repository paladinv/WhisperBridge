import Foundation

public enum TranscriptEditing {
    public static func speaker(for segment: TranscriptSegment, intervals: [(start: Double, end: Double, speakerID: UUID)]) -> UUID? {
        intervals.max { left, right in
            overlap(segment.start, segment.end, left.start, left.end) < overlap(segment.start, segment.end, right.start, right.end)
        }.flatMap { overlap(segment.start, segment.end, $0.start, $0.end) > 0 ? $0.speakerID : nil }
    }

    public static func assignSpeaker(_ speakerID: UUID?, to segmentIDs: Set<UUID>, in document: inout TranscriptDocument) {
        for index in document.segments.indices where segmentIDs.contains(document.segments[index].id) {
            document.segments[index].speakerID = speakerID
        }
        document.updatedAt = Date()
    }

    public static func delete(_ segmentIDs: Set<UUID>, in document: inout TranscriptDocument) {
        for index in document.segments.indices where segmentIDs.contains(document.segments[index].id) {
            document.segments[index].isDeleted = true
        }
        document.updatedAt = Date()
    }

    public static func restore(_ segmentIDs: Set<UUID>, in document: inout TranscriptDocument) {
        for index in document.segments.indices where segmentIDs.contains(document.segments[index].id) {
            document.segments[index].isDeleted = false
        }
        document.updatedAt = Date()
    }

    public static func replace(range: TranscriptTimeRange, with replacements: [TranscriptSegment], in document: inout TranscriptDocument) {
        document.segments.removeAll { $0.start < range.end && $0.end > range.start }
        document.segments.append(contentsOf: replacements)
        document.segments.sort { ($0.start, $0.end) < ($1.start, $1.end) }
        document.updatedAt = Date()
    }

    public static func split(segmentID: UUID, at time: Double, in document: inout TranscriptDocument) throws {
        guard let index = document.segments.firstIndex(where: { $0.id == segmentID }),
              time > document.segments[index].start, time < document.segments[index].end else {
            throw TranscriptCoreError.invalidTimeRange
        }
        let original = document.segments.remove(at: index)
        let wordCut = original.words.firstIndex { ($0.start ?? .greatestFiniteMagnitude) >= time } ?? original.words.count
        let leftWords = Array(original.words[..<wordCut])
        let rightWords = wordCut < original.words.count ? Array(original.words[wordCut...]) : []
        let fallbackWords = original.editedText.split(separator: " ")
        guard fallbackWords.count > 1 || !original.words.isEmpty else {
            throw TranscriptCoreError.invalidSetting("A one-word segment cannot be split without word timing.")
        }
        let fallbackCut = max(1, min(max(1, fallbackWords.count - 1), Int((time - original.start) / (original.end - original.start) * Double(fallbackWords.count))))
        let leftText = leftWords.isEmpty ? fallbackWords[..<fallbackCut].joined(separator: " ") : leftWords.map(\.rawText).joined()
        let rightText = rightWords.isEmpty ? fallbackWords[fallbackCut...].joined(separator: " ") : rightWords.map(\.rawText).joined()
        let left = TranscriptSegment(start: original.start, end: time, speakerID: original.speakerID, rawText: leftText, words: leftWords, fillersHidden: original.fillersHidden, timingIsApproximate: leftWords.isEmpty)
        let right = TranscriptSegment(start: time, end: original.end, speakerID: original.speakerID, rawText: rightText, words: rightWords, fillersHidden: original.fillersHidden, timingIsApproximate: rightWords.isEmpty)
        document.segments.insert(contentsOf: [left, right], at: index)
        document.updatedAt = Date()
    }

    public static func merge(_ segmentIDs: Set<UUID>, in document: inout TranscriptDocument) throws {
        let selected = document.segments.filter { segmentIDs.contains($0.id) }.sorted { $0.start < $1.start }
        guard selected.count >= 2 else { throw TranscriptCoreError.invalidSetting("Select at least two segments to merge.") }
        guard zip(selected, selected.dropFirst()).allSatisfy({ $0.end <= $1.start + 0.001 }) else {
            throw TranscriptCoreError.invalidSetting("Only adjacent transcript segments can be merged.")
        }
        let merged = TranscriptSegment(
            start: selected[0].start, end: selected.last!.end,
            speakerID: selected.allSatisfy({ $0.speakerID == selected[0].speakerID }) ? selected[0].speakerID : nil,
            rawText: selected.map(\.rawText).joined(separator: " "),
            editedText: selected.map(\.editedText).joined(separator: " "),
            words: selected.flatMap(\.words), isDeleted: selected.allSatisfy(\.isDeleted),
            fillersHidden: selected.allSatisfy(\.fillersHidden),
            hasOverlappingSpeech: selected.contains(where: \.hasOverlappingSpeech),
            timingIsApproximate: selected.contains(where: \.timingIsApproximate)
        )
        let insertion = document.segments.firstIndex { segmentIDs.contains($0.id) } ?? 0
        document.segments.removeAll { segmentIDs.contains($0.id) }
        document.segments.insert(merged, at: min(insertion, document.segments.count))
        document.updatedAt = Date()
    }

    private static func overlap(_ a0: Double, _ a1: Double, _ b0: Double, _ b1: Double) -> Double {
        max(0, min(a1, b1) - max(a0, b0))
    }
}

public enum FillerWordCleaner {
    public static let conservativeFillers: Set<String> = ["um", "umm", "uh", "uhh", "uhhh", "erm", "er"]

    public static func isFiller(_ value: String) -> Bool {
        let normalized = value.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        return conservativeFillers.contains(normalized)
    }

    public static func removingFillers(from text: String) -> String {
        let tokenizer = try? NSRegularExpression(pattern: #"\b(?:um+|uh+|erm|er)\b[,.]?\s*"#, options: [.caseInsensitive])
        let range = NSRange(text.startIndex..., in: text)
        let cleaned = tokenizer?.stringByReplacingMatches(in: text, range: range, withTemplate: "") ?? text
        return cleaned.replacingOccurrences(of: #"\s+([,.!?;:])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum TranscriptFormatting {
    public static func timestamp(_ seconds: Double, decimal: Character = ".") -> String {
        let milliseconds = max(0, Int((seconds * 1_000).rounded()))
        let hours = milliseconds / 3_600_000
        let minutes = milliseconds / 60_000 % 60
        let secs = milliseconds / 1_000 % 60
        let millis = milliseconds % 1_000
        return String(format: "%02d:%02d:%02d", hours, minutes, secs) + String(decimal) + String(format: "%03d", millis)
    }

    public static func renderedSegments(_ document: TranscriptDocument, compact: Bool) -> String {
        let speakers = Dictionary(uniqueKeysWithValues: document.speakers.map { ($0.id, $0.name) })
        return document.segments.filter { !$0.isDeleted }.map { segment in
            let time = compact ? "" : "[\(timestamp(segment.start))] "
            let speaker = segment.speakerID.flatMap { speakers[$0] }.map { "\($0): " } ?? ""
            return "\(time)\(speaker)\(segment.displayText)"
        }.joined(separator: "\n")
    }
}
