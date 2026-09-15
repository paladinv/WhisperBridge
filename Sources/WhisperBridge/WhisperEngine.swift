import Foundation
import whisper
import WhisperBridgeCore

struct TranscriptionResult: Sendable, Equatable {
    let text: String
    let detectedLanguage: String?
    let segments: [TranscriptSegment]
}

final class TranscriptionCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func cancel() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class CallbackBox: @unchecked Sendable {
    let cancellation: TranscriptionCancellation
    let progress: @Sendable (Int) -> Void

    init(cancellation: TranscriptionCancellation, progress: @escaping @Sendable (Int) -> Void) {
        self.cancellation = cancellation
        self.progress = progress
    }
}

actor WhisperEngine {
    func transcribe(
        samples: [Float],
        modelURL: URL,
        language: LanguageOption,
        timestampGranularity: TimestampGranularity = .segment,
        decodingOptions: WhisperDecodingOptions = DecodingPreset.balanced.options,
        timeOffset: Double = 0,
        cancellation: TranscriptionCancellation,
        progress: @escaping @Sendable (Int) -> Void
    ) throws -> TranscriptionResult {
        var contextParameters = whisper_context_default_params()
        contextParameters.use_gpu = true
        contextParameters.flash_attn = true
        guard let context = whisper_init_from_file_with_params(modelURL.path, contextParameters) else {
            throw AppFailure.modelInvalid
        }
        defer { whisper_free(context) }

        let box = CallbackBox(cancellation: cancellation, progress: progress)
        let pointer = Unmanaged.passUnretained(box).toOpaque()
        let options = try decodingOptions.validated()
        let sampling = options.strategy == .beam ? WHISPER_SAMPLING_BEAM_SEARCH : WHISPER_SAMPLING_GREEDY
        var parameters = whisper_full_default_params(sampling)
        parameters.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))
        parameters.translate = false
        parameters.no_context = true
        parameters.no_timestamps = timestampGranularity == .none
        parameters.token_timestamps = timestampGranularity == .word
        parameters.single_segment = false
        parameters.print_special = false
        parameters.print_progress = false
        parameters.print_realtime = false
        parameters.print_timestamps = false
        parameters.suppress_blank = true
        parameters.suppress_nst = true
        parameters.temperature = options.temperature
        parameters.temperature_inc = options.temperatureIncrement
        parameters.no_speech_thold = options.noSpeechThreshold
        parameters.logprob_thold = options.logProbabilityThreshold
        parameters.greedy.best_of = Int32(options.greedyBestOf)
        parameters.beam_search.beam_size = Int32(options.beamSize)
        parameters.beam_search.patience = options.patience
        // `detect_language` is a detection-only mode in whisper.cpp and returns before
        // decoding segments. Automatic transcription uses the special `auto` language
        // value with detection-only mode disabled.
        parameters.detect_language = false
        parameters.progress_callback = { _, _, value, userData in
            guard let userData else { return }
            Unmanaged<CallbackBox>.fromOpaque(userData).takeUnretainedValue().progress(Int(value))
        }
        parameters.progress_callback_user_data = pointer
        parameters.abort_callback = { userData in
            guard let userData else { return false }
            return Unmanaged<CallbackBox>.fromOpaque(userData).takeUnretainedValue().cancellation.isCancelled
        }
        parameters.abort_callback_user_data = pointer

        let languageCode = language.rawValue
        let run: (UnsafePointer<CChar>?) -> Int32 = { promptPointer in
            languageCode.withCString { languagePointer in
                parameters.language = languagePointer
                parameters.initial_prompt = promptPointer
                return samples.withUnsafeBufferPointer { buffer in
                    whisper_full(context, parameters, buffer.baseAddress, Int32(buffer.count))
                }
            }
        }
        let resultCode = if let prompt = options.initialPrompt, !prompt.isEmpty {
            prompt.withCString { run($0) }
        } else {
            run(nil)
        }
        if cancellation.isCancelled { throw CancellationError() }
        guard resultCode == 0 else { throw AppFailure.transcriptionFailed }

        var parts: [String] = []
        var segments: [TranscriptSegment] = []
        for index in 0..<whisper_full_n_segments(context) {
            let part = String(cString: whisper_full_get_segment_text(context, index))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !part.isEmpty else { continue }
            parts.append(part)
            let start = timeOffset + Double(whisper_full_get_segment_t0(context, index)) / 100
            let end = timeOffset + Double(whisper_full_get_segment_t1(context, index)) / 100
            var words: [TranscriptWord] = []
            if timestampGranularity == .word {
                for tokenIndex in 0..<whisper_full_n_tokens(context, index) {
                    let token = String(cString: whisper_full_get_token_text(context, index, tokenIndex))
                    let data = whisper_full_get_token_data(context, index, tokenIndex)
                    guard !token.isEmpty, data.t1 > data.t0 else { continue }
                    words.append(TranscriptWord(
                        start: timeOffset + Double(data.t0) / 100,
                        end: timeOffset + Double(data.t1) / 100,
                        rawText: token,
                        isFiller: FillerWordCleaner.isFiller(token)
                    ))
                }
            }
            segments.append(TranscriptSegment(start: start, end: max(start, end), rawText: part, words: words))
        }
        let text = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AppFailure.noSpeech }

        let languageID = whisper_full_lang_id(context)
        let detected = languageID >= 0 ? String(cString: whisper_lang_str_full(languageID)) : nil
        return TranscriptionResult(text: text, detectedLanguage: detected, segments: segments)
    }
}
