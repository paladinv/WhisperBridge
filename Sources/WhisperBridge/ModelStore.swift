import CryptoKit
import Foundation

struct ModelManifest: Sendable, Equatable {
    let filename: String
    let displayName: String
    let byteCount: Int64
    let sha256: String
    let downloadURL: URL

    static let recommended = ModelManifest(
        filename: "ggml-base.bin",
        displayName: "Whisper Base Multilingual",
        byteCount: 147_951_465,
        sha256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
        downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!
    )

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}
actor ModelStore {
    let directory: URL
    let manifest: ModelManifest

    init(directory: URL? = nil, manifest: ModelManifest = .recommended) {
        self.manifest = manifest
        if let directory {
            self.directory = directory
        } else if let override = ProcessInfo.processInfo.environment["WHISPERBRIDGE_DATA_DIR"] {
            self.directory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appending(path: "WhisperBridge/Models", directoryHint: .isDirectory)
        }
    }

    var modelURL: URL { directory.appending(path: manifest.filename) }

    func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func isInstalled() async -> Bool {
        do {
            try prepareDirectory()
            let values = try modelURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true, Int64(values.fileSize ?? 0) == manifest.byteCount else {
                return false
            }
            return try await Self.sha256(of: modelURL) == manifest.sha256
        } catch {
            return false
        }
    }

    func install(_ data: Data) async throws {
        try prepareDirectory()
        guard Int64(data.count) == manifest.byteCount else { throw AppFailure.modelInvalid }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == manifest.sha256 else { throw AppFailure.modelInvalid }

        let partial = directory.appending(path: manifest.filename + ".partial")
        try? FileManager.default.removeItem(at: partial)
        try data.write(to: partial, options: [.atomic])
        try? FileManager.default.removeItem(at: modelURL)
        try FileManager.default.moveItem(at: partial, to: modelURL)
    }

    func removeInvalidFiles() throws {
        try prepareDirectory()
        let partial = directory.appending(path: manifest.filename + ".partial")
        try? FileManager.default.removeItem(at: partial)
        if FileManager.default.fileExists(atPath: modelURL.path) {
            try FileManager.default.removeItem(at: modelURL)
        }
    }

    static func sha256(of url: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
                try Task.checkCancellation()
                hasher.update(data: data)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }
}

actor ModelDownloader {
    func download(_ manifest: ModelManifest) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 900
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: manifest.downloadURL)
        request.setValue("WhisperBridge/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw AppFailure.modelDownloadFailed("The server returned an unexpected response.")
            }
            guard Int64(data.count) == manifest.byteCount else { throw AppFailure.modelInvalid }
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AppFailure {
            throw error
        } catch {
            throw AppFailure.modelDownloadFailed(error.localizedDescription)
        }
    }
}
