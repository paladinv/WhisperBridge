import Foundation
import whisper

struct TranscriptionResult: Sendable, Equatable {
    let text: String
    let detectedLanguage: String?
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
        var parameters = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        parameters.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))
        parameters.translate = false
        parameters.no_context = true
        parameters.no_timestamps = true
        parameters.single_segment = false
        parameters.print_special = false
        parameters.print_progress = false
        parameters.print_realtime = false
        parameters.print_timestamps = false
        parameters.suppress_blank = true
        parameters.suppress_nst = true
        parameters.detect_language = language == .auto
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
        let resultCode = languageCode.withCString { languagePointer in
            parameters.language = languagePointer
            return samples.withUnsafeBufferPointer { buffer in
                whisper_full(context, parameters, buffer.baseAddress, Int32(buffer.count))
            }
        }
        if cancellation.isCancelled { throw CancellationError() }
        guard resultCode == 0 else { throw AppFailure.transcriptionFailed }

        var parts: [String] = []
        for index in 0..<whisper_full_n_segments(context) {
            let part = String(cString: whisper_full_get_segment_text(context, index))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty { parts.append(part) }
        }
        let text = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AppFailure.noSpeech }

        let languageID = whisper_full_lang_id(context)
        let detected = languageID >= 0 ? String(cString: whisper_lang_str_full(languageID)) : nil
        return TranscriptionResult(text: text, detectedLanguage: detected)
    }
}
