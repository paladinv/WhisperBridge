import Foundation

enum AppPhase: Equatable {
    case checkingModel
    case needsModel
    case downloadingModel
    case ready
    case inspectingAudio
    case decoding
    case transcribing
    case review
    case failed

    var label: String {
        switch self {
        case .checkingModel: "Checking speech model…"
        case .needsModel: "Speech model required"
        case .downloadingModel: "Downloading speech model…"
        case .ready: "Ready"
        case .inspectingAudio: "Checking audio…"
        case .decoding: "Preparing audio…"
        case .transcribing: "Transcribing locally…"
        case .review: "Transcript ready"
        case .failed: "Needs attention"
        }
    }
}

struct AudioSelection: Equatable, Sendable {
    let url: URL
    let displayName: String
    let byteCount: Int64
    let duration: TimeInterval

    var detail: String {
        let size = ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
        let seconds = Int(duration.rounded())
        return "\(size) · \(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

struct Transcript: Equatable, Sendable {
    let rawText: String
    var editedText: String
    let detectedLanguage: String?

    var isDirty: Bool { editedText != rawText }
}

enum LanguageOption: String, CaseIterable, Identifiable, Sendable {
    case auto
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case japanese = "ja"
    case chinese = "zh"
    case korean = "ko"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Detect automatically"
        case .english: "English"
        case .french: "French"
        case .spanish: "Spanish"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .japanese: "Japanese"
        case .chinese: "Chinese"
        case .korean: "Korean"
        }
    }
}

enum FilePolicy {
    static let maximumBytes: Int64 = 500 * 1_024 * 1_024
    static let maximumDuration: TimeInterval = 7_200
    static let allowedExtensions: Set<String> = ["wav", "mp3", "m4a", "aac", "flac"]

    static func validate(url: URL, byteCount: Int64, duration: TimeInterval) throws {
        guard allowedExtensions.contains(url.pathExtension.lowercased()) else {
            throw AppFailure.unsupportedFormat
        }
        guard byteCount <= maximumBytes else { throw AppFailure.fileTooLarge }
        guard duration <= maximumDuration else { throw AppFailure.audioTooLong }
        guard duration.isFinite, duration > 0 else { throw AppFailure.unreadableAudio }
    }
}

enum AppFailure: LocalizedError, Equatable {
    case unsupportedFormat
    case fileTooLarge
    case audioTooLong
    case unreadableAudio
    case noAudioTrack
    case decodeFailed(String)
    case modelDownloadFailed(String)
    case modelInvalid
    case modelUnavailable
    case transcriptionFailed
    case noSpeech
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "Choose a WAV, MP3, M4A, AAC, or FLAC audio file."
        case .fileTooLarge: "This file is larger than the 500 MiB limit."
        case .audioTooLong: "This recording is longer than the 2-hour limit."
        case .unreadableAudio: "This file does not contain readable audio."
        case .noAudioTrack: "No audio track was found in this file."
        case .decodeFailed(let detail): "The audio could not be prepared. \(detail)"
        case .modelDownloadFailed(let detail): "The speech model could not be downloaded. \(detail)"
        case .modelInvalid: "The speech model is incomplete or did not pass verification. Download it again."
        case .modelUnavailable: "Download the speech model before transcribing."
        case .transcriptionFailed: "Whisper could not transcribe this recording."
        case .noSpeech: "No speech was detected. Try another recording or check its volume."
        case .saveFailed(let detail): "The transcript could not be saved. \(detail)"
        }
    }
}
