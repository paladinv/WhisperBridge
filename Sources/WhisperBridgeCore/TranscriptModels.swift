import Foundation

public enum TimestampGranularity: String, Codable, CaseIterable, Sendable {
    case none
    case segment
    case word
}

public enum DecodingStrategy: String, Codable, CaseIterable, Sendable {
    case greedy
    case beam
}

public enum DecodingPreset: String, Codable, CaseIterable, Sendable {
    case fast
    case balanced
    case accurate

    public var title: String { rawValue.capitalized }

    public var options: WhisperDecodingOptions {
        switch self {
        case .fast:
            WhisperDecodingOptions(strategy: .greedy, greedyBestOf: 1)
        case .balanced:
            WhisperDecodingOptions(strategy: .greedy, greedyBestOf: 5)
        case .accurate:
            WhisperDecodingOptions(strategy: .beam, beamSize: 5, patience: 1)
        }
    }
}

public struct WhisperDecodingOptions: Codable, Equatable, Sendable {
    public var strategy: DecodingStrategy
    public var beamSize: Int
    public var greedyBestOf: Int
    public var patience: Float
    public var temperature: Float
    public var temperatureIncrement: Float
    public var initialPrompt: String?
    public var noSpeechThreshold: Float
    public var logProbabilityThreshold: Float

    public init(
        strategy: DecodingStrategy = .greedy,
        beamSize: Int = 5,
        greedyBestOf: Int = 5,
        patience: Float = 1,
        temperature: Float = 0,
        temperatureIncrement: Float = 0.2,
        initialPrompt: String? = nil,
        noSpeechThreshold: Float = 0.6,
        logProbabilityThreshold: Float = -1
    ) {
        self.strategy = strategy
        self.beamSize = beamSize
        self.greedyBestOf = greedyBestOf
        self.patience = patience
        self.temperature = temperature
        self.temperatureIncrement = temperatureIncrement
        self.initialPrompt = initialPrompt
        self.noSpeechThreshold = noSpeechThreshold
        self.logProbabilityThreshold = logProbabilityThreshold
    }

    public func validated() throws -> Self {
        guard (1...10).contains(beamSize) else { throw TranscriptCoreError.invalidSetting("Beam size must be from 1 through 10.") }
        guard (1...10).contains(greedyBestOf) else { throw TranscriptCoreError.invalidSetting("Greedy best-of must be from 1 through 10.") }
        guard (0...2).contains(patience) else { throw TranscriptCoreError.invalidSetting("Beam patience must be from 0 through 2.") }
        guard (0...1).contains(temperature), (0...1).contains(temperatureIncrement) else {
            throw TranscriptCoreError.invalidSetting("Temperature values must be from 0 through 1.")
        }
        guard (0...1).contains(noSpeechThreshold), (-5...0).contains(logProbabilityThreshold) else {
            throw TranscriptCoreError.invalidSetting("The speech thresholds are outside their supported range.")
        }
        guard (initialPrompt?.count ?? 0) <= 1_000 else { throw TranscriptCoreError.invalidSetting("The initial prompt is longer than 1,000 characters.") }
        return self
    }
}

public struct TranscriptTimeRange: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double

    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }

    public func validated(duration: Double? = nil) throws -> Self {
        guard start.isFinite, end.isFinite, start >= 0, end > start else {
            throw TranscriptCoreError.invalidTimeRange
        }
        if let duration, end > duration + 0.001 { throw TranscriptCoreError.invalidTimeRange }
        return self
    }
}

public struct TranscriptWord: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var start: Double?
    public var end: Double?
    public var rawText: String
    public var isFiller: Bool

    public init(id: UUID = UUID(), start: Double? = nil, end: Double? = nil, rawText: String, isFiller: Bool = false) {
        self.id = id
        self.start = start
        self.end = end
        self.rawText = rawText
        self.isFiller = isFiller
    }
}

public struct TranscriptSpeaker: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var colorIndex: Int

    public init(id: UUID = UUID(), name: String, colorIndex: Int = 0) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
    }
}

public struct TranscriptSegment: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var start: Double
    public var end: Double
    public var speakerID: UUID?
    public var rawText: String
    public var editedText: String
    public var words: [TranscriptWord]
    public var isDeleted: Bool
    public var fillersHidden: Bool
    public var hasOverlappingSpeech: Bool
    public var timingIsApproximate: Bool

    public init(
        id: UUID = UUID(), start: Double, end: Double, speakerID: UUID? = nil,
        rawText: String, editedText: String? = nil, words: [TranscriptWord] = [],
        isDeleted: Bool = false, fillersHidden: Bool = false,
        hasOverlappingSpeech: Bool = false, timingIsApproximate: Bool = false
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.speakerID = speakerID
        self.rawText = rawText
        self.editedText = editedText ?? rawText
        self.words = words
        self.isDeleted = isDeleted
        self.fillersHidden = fillersHidden
        self.hasOverlappingSpeech = hasOverlappingSpeech
        self.timingIsApproximate = timingIsApproximate
    }

    public var displayText: String {
        guard fillersHidden else { return editedText }
        return FillerWordCleaner.removingFillers(from: editedText)
    }
}

public struct TranscriptDocument: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var sourceFilename: String
    public var audioAssetID: String?
    public var duration: Double
    public var detectedLanguage: String?
    public var modelID: String
    public var modelRevision: String
    public var sourceRange: TranscriptTimeRange?
    public var timestampGranularity: TimestampGranularity
    public var decodingOptions: WhisperDecodingOptions
    public var speakers: [TranscriptSpeaker]
    public var segments: [TranscriptSegment]
    public var createdAt: Date
    public var updatedAt: Date
    public var legacyMetadata: [String: String]

    public init(
        id: UUID = UUID(), title: String, sourceFilename: String, audioAssetID: String? = nil,
        duration: Double, detectedLanguage: String? = nil, modelID: String,
        modelRevision: String = "", sourceRange: TranscriptTimeRange? = nil,
        timestampGranularity: TimestampGranularity = .segment,
        decodingOptions: WhisperDecodingOptions = DecodingPreset.balanced.options,
        speakers: [TranscriptSpeaker] = [], segments: [TranscriptSegment],
        createdAt: Date = Date(), updatedAt: Date = Date(), legacyMetadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.sourceFilename = sourceFilename
        self.audioAssetID = audioAssetID
        self.duration = duration
        self.detectedLanguage = detectedLanguage
        self.modelID = modelID
        self.modelRevision = modelRevision
        self.sourceRange = sourceRange
        self.timestampGranularity = timestampGranularity
        self.decodingOptions = decodingOptions
        self.speakers = speakers
        self.segments = segments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.legacyMetadata = legacyMetadata
    }

    public var activeText: String {
        segments.filter { !$0.isDeleted }.map(\.displayText).filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

public struct TranscriptSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let sourceFilename: String
    public let duration: Double
    public let updatedAt: Date
    public let speakerNames: [String]
}

public struct TranscriptSearchResult: Identifiable, Equatable, Sendable {
    public var id: String { "\(transcriptID.uuidString):\(segmentID.uuidString)" }
    public let transcriptID: UUID
    public let segmentID: UUID
    public let title: String
    public let speakerName: String?
    public let snippet: String
    public let start: Double
    public let rank: Double
}

public enum TranscriptCoreError: LocalizedError, Equatable {
    case invalidSetting(String)
    case invalidTimeRange
    case invalidArchive(String)
    case database(String)
    case audioCopy(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSetting(let message): message
        case .invalidTimeRange: "The selected range must start at or after zero and end after its start within the recording."
        case .invalidArchive(let message): "The STTTTS project is invalid. \(message)"
        case .database(let message): "The transcript library could not be updated. \(message)"
        case .audioCopy(let message): "The audio could not be copied into the library. \(message)"
        }
    }
}
