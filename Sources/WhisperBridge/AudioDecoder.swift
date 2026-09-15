@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import WhisperBridgeCore

struct AudioDecoder: Sendable {
    static let targetSampleRate = 16_000.0

    func inspect(_ url: URL) async throws -> AudioSelection {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .nameKey])
        guard values.isRegularFile == true else { throw AppFailure.unreadableAudio }
        let byteCount = Int64(values.fileSize ?? 0)

        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let durationValue = try await asset.load(.duration)
        let duration = durationValue.seconds
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw AppFailure.noAudioTrack }
        try FilePolicy.validate(url: url, byteCount: byteCount, duration: duration)

        return AudioSelection(
            url: url,
            displayName: values.name ?? url.lastPathComponent,
            byteCount: byteCount,
            duration: duration
        )
    }

    func decode(
        _ selection: AudioSelection,
        range: TranscriptTimeRange? = nil,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [Float] {
        try await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: selection.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { throw AppFailure.noAudioTrack }
            let reader = try AVAssetReader(asset: asset)
            if let range = try range?.validated(duration: selection.duration) {
                reader.timeRange = CMTimeRange(
                    start: CMTime(seconds: range.start, preferredTimescale: 600),
                    duration: CMTime(seconds: range.end - range.start, preferredTimescale: 600)
                )
            }
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: AudioDecoder.targetSampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else {
                throw AppFailure.decodeFailed("The audio decoder does not support this encoding.")
            }
            reader.add(output)
            guard reader.startReading() else {
                throw AppFailure.decodeFailed(reader.error?.localizedDescription ?? "The decoder could not start.")
            }

            let estimatedCount = min(
                Int((range.map { $0.end - $0.start } ?? selection.duration) * AudioDecoder.targetSampleRate),
                Int(FilePolicy.maximumDuration * AudioDecoder.targetSampleRate)
            )
            var samples: [Float] = []
            samples.reserveCapacity(estimatedCount)

            while let sampleBuffer = output.copyNextSampleBuffer() {
                if Task.isCancelled {
                    reader.cancelReading()
                    throw CancellationError()
                }
                guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
                let byteCount = CMBlockBufferGetDataLength(block)
                guard byteCount > 0, byteCount % MemoryLayout<Float>.stride == 0 else { continue }
                var data = Data(count: byteCount)
                let status = data.withUnsafeMutableBytes { bytes in
                    guard let address = bytes.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
                    return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: byteCount, destination: address)
                }
                guard status == kCMBlockBufferNoErr else {
                    reader.cancelReading()
                    throw AppFailure.decodeFailed("The decoded samples could not be read.")
                }
                data.withUnsafeBytes { bytes in
                    samples.append(contentsOf: bytes.bindMemory(to: Float.self))
                }

                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                let start = range?.start ?? 0
                let duration = range.map { $0.end - $0.start } ?? selection.duration
                if time.isFinite, duration > 0 {
                    progress(min(max((time - start) / duration, 0), 0.99))
                }
            }

            guard reader.status == .completed else {
                if reader.status == .cancelled { throw CancellationError() }
                throw AppFailure.decodeFailed(reader.error?.localizedDescription ?? "The decoder stopped unexpectedly.")
            }
            guard !samples.isEmpty else { throw AppFailure.unreadableAudio }
            progress(1)
            return samples
        }.value
    }
}
