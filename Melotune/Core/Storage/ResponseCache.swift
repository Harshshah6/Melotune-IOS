import Foundation

/// Disk-backed response cache for API calls.
///
/// Port of the Android app's cached responses (`SharedPreferenceManager` kept song/album/
/// playlist/artist/search responses in Room). Every successful response is written here,
/// and when the network fails the cached copy is returned so browsing and detail screens
/// keep working offline.
final class ResponseCache {
    static let shared = ResponseCache()

    private let directory: URL
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.harsh.shah.melotune.response-cache", qos: .utility)

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("api-cache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func store(_ data: Data, for url: URL) {
        let file = fileURL(for: url)
        ioQueue.async { [data] in
            try? data.write(to: file, options: .atomic)
        }
    }

    func data(for url: URL) -> Data? {
        try? Data(contentsOf: fileURL(for: url))
    }

    func clear() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func sizeInBytes() -> Int64 {
        Self.directorySize(directory)
    }

    static func directorySize(_ dir: URL) -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys) else {
            return 0
        }
        return files.reduce(into: Int64(0)) { total, file in
            let values = try? file.resourceValues(forKeys: Set(keys))
            total += Int64(values?.fileSize ?? 0)
        }
    }

    private func fileURL(for url: URL) -> URL {
        directory.appendingPathComponent(Self.hash(url.absoluteString) + ".json")
    }

    /// Stable, dependency-free FNV-1a hash used as the cache filename.
    static func hash(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x1_0000_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
