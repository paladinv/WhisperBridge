@preconcurrency import MLX
import MLXAudioSTT
import Foundation

struct HelperSegment: Codable, Equatable, Sendable {
    let start: Double?
    let end: Double?
    let text: String
    let speaker: String?
}

struct MLXTranscriptionResult: Sendable {
    let text: String
    let detectedLanguage: String?
    let segments: [HelperSegment]
}

struct MLXEngine: Sendable {
    func transcribe(
        samples: [Float],
        engine: String,
        repository: String,
        modelDirectory: URL,
        language: String,
        outputStyle: String
    ) async throws -> MLXTranscriptionResult {
        let meanSquare = samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(max(samples.count, 1))
        guard meanSquare > 1e-8 else { throw AppFailure.noSpeech }
        guard engine != "canaryQwen" else {
            throw CLIError("model_unavailable", "Canary-Qwen is unavailable until a verified native checkpoint is released.")
        }
        guard let modelType = Self.modelType(for: engine) else {
            throw CLIError("unsupported_engine", "The selected speech engine is unsupported.")
        }

        let payload = modelDirectory
            .appendingPathComponent("mlx-audio", isDirectory: true)
            .appendingPathComponent(repository.replacingOccurrences(of: "/", with: "_"), isDirectory: true)
        guard FileManager.default.fileExists(atPath: payload.appendingPathComponent("config.json").path) else {
            throw CLIError("model_unavailable", "The selected speech model is incomplete.")
        }

        // Some MLX Audio adapters expose only repository-based loaders. Point every
        // supported cache variable at this already verified revision before loading.
        // ModelUtils will therefore reuse payload and cannot fall back to a host-global cache.
        setenv("HF_HUB_CACHE", modelDirectory.path, 1)
        setenv("HF_HOME", modelDirectory.path, 1)
        setenv("TRANSFORMERS_CACHE", modelDirectory.path, 1)
        setenv("MLX_HOME", modelDirectory.path, 1)
        let model = try await STT.loadModel(modelRepo: repository, modelType: modelType)
        try Task.checkCancellation()
        if engine == "moonshine" {
            return try Self.transcribeMoonshine(
                samples: samples,
                model: model,
                language: language
            )
        }
        let parameters = STTGenerateParameters(
            maxTokens: outputStyle == "speakerTimestamped" ? 8192 : 4096,
            language: Self.runtimeLanguage(language, engine: engine),
            chunkDuration: 30
        )
        let result = model.generate(audio: MLXArray(samples), generationParameters: parameters)
        try Task.checkCancellation()

        let normalized = Self.normalize(result.text)
        guard !normalized.isEmpty else { throw AppFailure.noSpeech }
        let suppliedSegments = Self.convertSegments(result.segments)
        return MLXTranscriptionResult(
            text: normalized,
            detectedLanguage: result.language,
            segments: suppliedSegments.isEmpty && outputStyle == "speakerTimestamped"
                ? Self.parseSpeakerTranscript(normalized)
                : suppliedSegments
        )
    }

    private static func transcribeMoonshine(
        samples: [Float],
        model: any STTGenerationModel,
        language: String
    ) throws -> MLXTranscriptionResult {
        var textParts: [String] = []
        var segments: [HelperSegment] = []
        for range in moonshineChunkRanges(samples) {
            try Task.checkCancellation()
            let chunk = Array(samples[range])
            let output = model.generate(
                audio: MLXArray(chunk),
                generationParameters: STTGenerateParameters(
                    maxTokens: 200,
                    language: language == "auto" ? nil : language,
                    chunkDuration: 8
                )
            )
            let text = normalize(output.text)
            if !text.isEmpty {
                textParts.append(text)
                segments.append(HelperSegment(
                    start: Double(range.lowerBound) / 16_000,
                    end: Double(range.upperBound) / 16_000,
                    text: text,
                    speaker: nil
                ))
            }
        }
        let text = textParts.joined(separator: " ")
        guard !text.isEmpty else { throw AppFailure.noSpeech }
        return MLXTranscriptionResult(text: text, detectedLanguage: "en", segments: segments)
    }

    private static func moonshineChunkRanges(_ samples: [Float]) -> [Range<Int>] {
        let sampleRate = 16_000
        let minimum = 4 * sampleRate
        let maximum = 8 * sampleRate
        let analysisRadius = sampleRate / 20
        let step = sampleRate / 20
        var ranges: [Range<Int>] = []
        var start = 0
        while samples.count - start > maximum {
            var bestEnd = start + maximum
            var bestEnergy = Double.greatestFiniteMagnitude
            var candidate = start + minimum
            while candidate <= start + maximum {
                let lower = max(start, candidate - analysisRadius)
                let upper = min(samples.count, candidate + analysisRadius)
                let energy = samples[lower..<upper].reduce(0.0) { $0 + Double(abs($1)) } / Double(upper - lower)
                if energy < bestEnergy {
                    bestEnergy = energy
                    bestEnd = candidate
                }
                candidate += step
            }
            ranges.append(start..<bestEnd)
            start = bestEnd
        }
        if start < samples.count { ranges.append(start..<samples.count) }
        return ranges
    }

    static func modelType(for engine: String) -> String? {
        switch engine {
        case "moonshine": "moonshine"
        case "parakeet": "parakeet"
        case "moss": "moss_transcribe_diarize"
        case "cohere": "cohere"
        case "granite": "granite_speech"
        default: nil
        }
    }

    static func runtimeLanguage(_ language: String, engine: String) -> String? {
        guard language != "auto" else { return nil }
        if engine == "granite" {
            return [
                "en": "English", "fr": "French", "de": "German", "es": "Spanish",
                "pt": "Portuguese", "ja": "Japanese",
            ][language] ?? language
        }
        return language
    }

    static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func convertSegments(_ values: [[String: Any]]?) -> [HelperSegment] {
        (values ?? []).compactMap { value in
            let text = (value["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return HelperSegment(
                start: number(value["start"] ?? value["start_time"]),
                end: number(value["end"] ?? value["end_time"]),
                text: text,
                speaker: value["speaker"] as? String ?? value["speaker_id"] as? String
            )
        }
    }

    static func parseSpeakerTranscript(_ text: String) -> [HelperSegment] {
        let pattern = #"\[([0-9]+(?:\.[0-9]+)?)\]\[(S[0-9]+)\](.*?)\[([0-9]+(?:\.[0-9]+)?)\]"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let startRange = Range(match.range(at: 1), in: text),
                  let speakerRange = Range(match.range(at: 2), in: text),
                  let textRange = Range(match.range(at: 3), in: text),
                  let endRange = Range(match.range(at: 4), in: text),
                  let start = Double(text[startRange]),
                  let end = Double(text[endRange]) else { return nil }
            let content = text[textRange].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return nil }
            return HelperSegment(start: start, end: end, text: content, speaker: String(text[speakerRange]))
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Float { return Double(value) }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}
