import Foundation

/// Disk cache for audio streams so tracks that have already played can play offline.
///
/// Port of the Android app's ExoPlayer `SimpleCache` (bounded LRU). The track is streamed
/// normally the first time and downloaded into this cache in the background; later plays
/// come from the cached file. Caching is skipped on expensive (cellular) connections.
final class AudioCache {
    static let shared = AudioCache()

    private let directory: URL
    private let fileManager = FileManager.default
    private let maxBytes: Int64 = 300 * 1024 * 1024
    private let lock = NSLock()
    private var inFlight: Set<String> = []
    private let session: URLSession

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("audio-cache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600
        config.isDiscretionary = false
        session = URLSession(configuration: config)
    }

    /// Local file for a remote stream, if it has already been cached.
    func cachedFile(for remoteURL: URL) -> URL? {
        let file = fileURL(for: remoteURL)
        return fileManager.fileExists(atPath: file.path) ? file : nil
    }

    /// Downloads a stream into the cache. No-op if present, in flight, or caching is off.
    func cache(_ remoteURL: URL) {
        guard Preferences.shared.storeInCache else { return }
        // Avoid doubling cellular data usage; only pre-cache on cheap connections.
        guard NetworkMonitor.shared.isConnected, !NetworkMonitor.shared.isExpensive else { return }

        let key = remoteURL.absoluteString
        let file = fileURL(for: remoteURL)

        lock.lock()
        if inFlight.contains(key) || fileManager.fileExists(atPath: file.path) {
            lock.unlock()
            return
        }
        inFlight.insert(key)
        lock.unlock()

        let task = session.downloadTask(with: remoteURL) { [weak self] tempURL, response, error in
            guard let self else { return }
            defer {
                self.lock.lock()
                self.inFlight.remove(key)
                self.lock.unlock()
            }
            guard let tempURL, error == nil,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return }
            try? self.fileManager.removeItem(at: file)
            try? self.fileManager.moveItem(at: tempURL, to: file)
            self.trim()
        }
        task.resume()
    }

    func clear() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func sizeInBytes() -> Int64 {
        ResponseCache.directorySize(directory)
    }

    /// Evicts the oldest files once the cache grows past `maxBytes`.
    private func trim() {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else {
            return
        }
        var entries: [(url: URL, date: Date, size: Int64)] = []
        var total: Int64 = 0
        for file in files {
            let values = try? file.resourceValues(forKeys: Set(keys))
            let size = Int64(values?.fileSize ?? 0)
            entries.append((file, values?.contentModificationDate ?? .distantPast, size))
            total += size
        }
        guard total > maxBytes else { return }
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
            if total <= maxBytes { break }
        }
    }

    private func fileURL(for remoteURL: URL) -> URL {
        let ext = remoteURL.pathExtension.isEmpty ? "mp4" : remoteURL.pathExtension
        return directory.appendingPathComponent(ResponseCache.hash(remoteURL.absoluteString) + "." + ext)
    }
}
