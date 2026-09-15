import Foundation
import FluidAudio

public struct DiarizationInterval: Equatable, Sendable {
    public let start: Double
    public let end: Double
    public let speakerID: UUID
    public let sourceLabel: String

    public init(start: Double, end: Double, speakerID: UUID, sourceLabel: String) {
        self.start = start
        self.end = end
        self.speakerID = speakerID
        self.sourceLabel = sourceLabel
    }
}

public struct DiarizationOutput: Equatable, Sendable {
    public let speakers: [TranscriptSpeaker]
    public let intervals: [DiarizationInterval]
}

public enum DiarizationService {
    public static let repositoryFolder = "speaker-diarization-coreml"
    public static let requiredFiles = [
        "Segmentation.mlmodelc", "FBank.mlmodelc", "Embedding.mlmodelc",
        "PldaRho.mlmodelc", "plda-parameters.json",
    ]

    /// Runs FluidAudio's offline pipeline only against an explicitly supplied,
    /// already-verified model directory. No default or host-global cache is used.
    @available(macOS 15.0, *)
    public static func process(
        samples: [Float],
        modelDirectory: URL,
        timeOffset: Double = 0,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> DiarizationOutput {
        guard !samples.isEmpty else { throw TranscriptCoreError.invalidSetting("Diarization needs decoded audio.") }
        let repositoryDirectory = modelDirectory.appending(path: repositoryFolder, directoryHint: .isDirectory)
        for relativePath in requiredFiles {
            let candidate = repositoryDirectory.appending(path: relativePath)
            guard FileManager.default.fileExists(atPath: candidate.path) else {
                throw TranscriptCoreError.invalidSetting("The verified diarization assets are incomplete (missing \(relativePath)).")
            }
        }

        // FluidAudio otherwise falls back to ModelHub downloads and its default
        // cache. Production assets are installed and verified by WhisperBridge.
        ModelHub.offlineMode = true
        let models = try await OfflineDiarizerModels.load(from: modelDirectory)
        let manager = OfflineDiarizerManager()
        manager.initialize(models: models)
        let result = try await manager.process(audio: samples) { completed, total in
            progress?(total > 0 ? Double(completed) / Double(total) : 0)
        }
        let labels = Array(Set(result.segments.map(\.speakerId))).sorted()
        let identities = Dictionary(uniqueKeysWithValues: labels.enumerated().map { index, label in
            (label, UUID())
        })
        let speakers = labels.enumerated().map { index, label in
            TranscriptSpeaker(id: identities[label]!, name: "Speaker \(index + 1)", colorIndex: index)
        }
        let intervals = result.segments.compactMap { item -> DiarizationInterval? in
            guard let speakerID = identities[item.speakerId] else { return nil }
            return DiarizationInterval(
                start: Double(item.startTimeSeconds) + timeOffset,
                end: Double(item.endTimeSeconds) + timeOffset,
                speakerID: speakerID,
                sourceLabel: item.speakerId
            )
        }.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
        return DiarizationOutput(speakers: speakers, intervals: intervals)
    }

    public static func applying(_ output: DiarizationOutput, to segments: [TranscriptSegment]) -> [TranscriptSegment] {
        let tuples = output.intervals.map { ($0.start, $0.end, $0.speakerID) }
        return segments.map { source in
            var segment = source
            segment.speakerID = TranscriptEditing.speaker(for: segment, intervals: tuples)
            let overlaps = output.intervals.filter { max(0, min(segment.end, $0.end) - max(segment.start, $0.start)) > 0 }
            segment.hasOverlappingSpeech = Set(overlaps.map(\.speakerID)).count > 1
            return segment
        }
    }
}
