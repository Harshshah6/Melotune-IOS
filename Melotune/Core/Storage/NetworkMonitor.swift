import Foundation
import Network
import Observation

/// Tracks connectivity so the app can fall back to cached data gracefully and avoid
/// pre-caching audio over cellular. Mirrors the role of Android's `NetworkChangeReceiver`.
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected = true
    private(set) var isExpensive = false

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            DispatchQueue.main.async {
                self?.isConnected = connected
                self?.isExpensive = expensive
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.harsh.shah.melotune.network"))
    }
}
