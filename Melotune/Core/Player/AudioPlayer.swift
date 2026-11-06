import AVFoundation
import MediaPlayer
import Observation
import UIKit

/// Port of the Android `MusicPlayerManager` built on AVPlayer.
///
/// The Android app keeps a queue of *song ids* and re-fetches the stream URL for each
/// track when it starts, so the exact same flow is used here: `setQueue` + `playTrack(id:)`,
/// with next/previous walking the id queue and honouring shuffle/repeat.
@MainActor
@Observable
final class AudioPlayer {
    static let shared = AudioPlayer()

    enum RepeatMode: Int {
        case off, one, all
    }

    // MARK: - Observable state

    private(set) var currentTrack: Song?
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var queue: [String] = []
    private(set) var queuePosition = -1

    var isShuffleEnabled = false
    var repeatMode: RepeatMode = .off

    var playbackSpeed: Float = 1.0 {
        didSet { applyRate() }
    }

    // MARK: - Private

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var artworkTask: Task<Void, Never>?
    private var autoplayTask: Task<Void, Never>?
    private var isTransitioning = false
    private var artworkCache: [String: UIImage] = [:]

    private init() {
        configureAudioSession()
        configurePlayer()
        configureRemoteCommands()
        observeInterruptions()
    }

    // MARK: - Setup

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AudioPlayer: failed to configure AVAudioSession – \(error.localizedDescription)")
        }
    }

    private func configurePlayer() {
        player.actionAtItemEnd = .none
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = player.timeControlStatus == .playing
                if self.isPlaying { self.isBuffering = false }
                self.updateNowPlaying()
            }
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if let itemDuration = self.player.currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
                self.refreshNowPlayingElapsed()
            }
        }
    }

    private func observeInterruptions() {
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let info = note.userInfo,
                  let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            Task { @MainActor in
                guard let self else { return }
                switch type {
                case .began:
                    self.player.pause()
                case .ended:
                    if let opts = info[AVAudioSessionInterruptionOptionKey] as? UInt,
                       AVAudioSession.InterruptionOptions(rawValue: opts).contains(.shouldResume) {
                        self.player.play()
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
        center.changePlaybackRateCommand.isEnabled = false
    }

    // MARK: - Queue

    /// Replaces the queue and starts playing. Mirrors how the Android lists set
    /// `MusicPlayerManager.trackQueue` / `track_position` then call `playTrack()`.
    func setQueue(_ ids: [String], startAt index: Int = 0, autoPlay: Bool = true) {
        queue = ids
        guard !ids.isEmpty else {
            queuePosition = -1
            return
        }
        queuePosition = min(max(index, 0), ids.count - 1)
        if autoPlay {
            playTrack(id: ids[queuePosition])
        }
    }

    func playNext(id: String) {
        guard !id.isEmpty else { return }
        cancelAutoplay()
        var updated = queue
        updated.removeAll { $0 == id }
        let insertPosition = queuePosition == -1 ? 0 : queuePosition + 1
        if insertPosition >= updated.count {
            updated.append(id)
        } else {
            updated.insert(id, at: insertPosition)
        }
        queue = updated
        if queuePosition == -1 {
            queuePosition = 0
            playTrack(id: id)
        }
    }

    func addToQueue(id: String) {
        guard !id.isEmpty else { return }
        cancelAutoplay()
        var updated = queue
        if !updated.contains(id) { updated.append(id) }
        queue = updated
        if queuePosition == -1 {
            queuePosition = 0
            playTrack(id: id)
        }
    }

    func removeFromQueue(at offsets: IndexSet) {
        let playingId = queuePosition >= 0 && queuePosition < queue.count ? queue[queuePosition] : nil
        queue.remove(atOffsets: offsets)
        if let playingId, let newIndex = queue.firstIndex(of: playingId) {
            queuePosition = newIndex
        } else if queue.isEmpty {
            queuePosition = -1
        } else {
            queuePosition = min(queuePosition, queue.count - 1)
        }
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        guard queuePosition >= 0, queuePosition < queue.count else {
            queue.move(fromOffsets: source, toOffset: destination)
            return
        }
        let playingId = queue[queuePosition]
        queue.move(fromOffsets: source, toOffset: destination)
        if let newIndex = queue.firstIndex(of: playingId) {
            queuePosition = newIndex
        }
    }

    // MARK: - Transport

    func playTrack(id: String) {
        guard !id.isEmpty else {
            isTransitioning = false
            return
        }
        cancelAutoplay()
        isTransitioning = true
        isBuffering = true

        Task { @MainActor in
            do {
                let response = try await ApiClient.shared.retrieveSongById(id)
                guard response.success == true, let first = response.data?.first else {
                    self.isTransitioning = false
                    self.isBuffering = false
                    return
                }
                self.currentTrack = first
                let urlString = self.streamURL(from: first.downloadUrl)
                guard !urlString.isEmpty, let url = URL(string: urlString) else {
                    self.isTransitioning = false
                    self.isBuffering = false
                    return
                }
                if let cached = AudioCache.shared.cachedFile(for: url) {
                    self.load(url: cached, track: first)
                } else {
                    AudioCache.shared.cache(url)
                    self.load(url: url, track: first)
                }
                self.recordHistory(for: first)
            } catch {
                print("AudioPlayer: playTrack failed – \(error.localizedDescription)")
                self.isTransitioning = false
                self.isBuffering = false
            }
        }
    }

    private func load(url: URL, track: Song) {
        let item = AVPlayerItem(url: url)
        itemStatusObservation?.invalidate()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }

        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isTransitioning = false
                    self.isBuffering = false
                    if item.duration.seconds.isFinite { self.duration = item.duration.seconds }
                case .failed:
                    self.isTransitioning = false
                    self.isBuffering = false
                default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleTrackEnded() }
        }

        player.replaceCurrentItem(with: item)
        player.play()
        applyRate()
        duration = track.duration ?? 0
        currentTime = 0
        updateNowPlaying(artwork: nil)
        refreshArtwork(for: track)
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else if player.currentItem == nil {
            if let id = currentTrack?.id { playTrack(id: id) }
        } else {
            player.play()
            applyRate()
        }
        updateNowPlaying()
    }

    func resume() {
        guard player.currentItem != nil else { return }
        player.play()
        applyRate()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: Double) {
        let clamped = max(0, seconds)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
        refreshNowPlayingElapsed()
    }

    func next() {
        guard !queue.isEmpty, queuePosition < queue.count else { return }
        if queuePosition >= queue.count - 1 {
            switch repeatMode {
            case .one:
                seek(to: 0)
                resume()
                return
            case .all:
                queuePosition = 0
            case .off:
                if Preferences.shared.isAutoplayEnabled, let current = currentTrack {
                    fetchAutoplay(from: current)
                    return
                }
                seek(to: 0)
                resume()
                return
            }
        } else {
            if isShuffleEnabled, queue.count > 1 {
                var candidate = queuePosition
                while candidate == queuePosition { candidate = Int.random(in: 0..<queue.count) }
                queuePosition = candidate
            } else {
                queuePosition += 1
            }
        }
        playTrack(id: queue[queuePosition])
    }

    func previous() {
        guard !queue.isEmpty else {
            seek(to: 0)
            return
        }
        if currentTime > 3 {
            seek(to: 0)
            resume()
            return
        }
        if queuePosition <= 0 {
            if repeatMode == .all {
                queuePosition = queue.count - 1
            } else {
                seek(to: 0)
                resume()
                return
            }
        } else {
            if isShuffleEnabled, queue.count > 1 {
                queuePosition = Int.random(in: 0..<queue.count)
            } else {
                queuePosition -= 1
            }
        }
        playTrack(id: queue[queuePosition])
    }

    // MARK: - Autoplay

    private func handleTrackEnded() {
        if repeatMode == .one {
            seek(to: 0)
            resume()
        } else {
            next()
        }
    }

    private func cancelAutoplay() {
        autoplayTask?.cancel()
        autoplayTask = nil
    }

    private func fetchAutoplay(from song: Song) {
        guard autoplayTask == nil else { return }
        let snapshotPosition = queuePosition
        let snapshotId = song.id
        autoplayTask = Task { @MainActor in
            let recommendations = await RecommendationService.recommendations(for: song, limit: 10)
            defer { self.autoplayTask = nil }
            guard !Task.isCancelled else { return }
            guard self.queuePosition == snapshotPosition, self.currentTrack?.id == snapshotId else { return }
            let newIds = recommendations.compactMap { $0.id }.filter { !self.queue.contains($0) }
            guard !newIds.isEmpty else {
                self.seek(to: 0)
                self.resume()
                return
            }
            self.queue.append(contentsOf: newIds)
            if self.queuePosition < self.queue.count - 1 {
                self.queuePosition += 1
                self.playTrack(id: self.queue[self.queuePosition])
            }
        }
    }

    // MARK: - Stream URL resolution (port of getDownloadUrl)

    private func streamURL(from list: [JDownloadUrl]?) -> String {
        guard let list, !list.isEmpty else { return "" }
        let quality = Preferences.shared.trackQuality
        var best = ""
        for item in list {
            guard let url = item.url else { continue }
            if url.hasPrefix("https:") && item.quality == quality { return url }
            if item.quality == quality { best = url }
        }
        if !best.isEmpty {
            return best.replacingOccurrences(of: "http:", with: "https:")
        }
        guard let last = list.last?.url else { return "" }
        return last.replacingOccurrences(of: "http:", with: "https:")
    }

    // MARK: - Now Playing / lock screen

    private func updateNowPlaying(artwork: UIImage? = nil) {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.displayName,
            MPMediaItemPropertyArtist: track.artists?.all?.compactMap { $0.name }.joined(separator: ", ") ?? "",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackSpeed) : 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        let resolvedDuration = duration > 0 ? duration : (track.duration ?? 0)
        if resolvedDuration > 0 { info[MPMediaItemPropertyPlaybackDuration] = resolvedDuration }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        } else if let existing = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] {
            info[MPMediaItemPropertyArtwork] = existing
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func refreshNowPlayingElapsed() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackSpeed) : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func refreshArtwork(for track: Song) {
        guard let urlString = track.artworkURL, let url = URL(string: urlString) else { return }
        if let cached = artworkCache[urlString] {
            updateNowPlaying(artwork: cached)
            return
        }
        artworkTask?.cancel()
        artworkTask = Task { @MainActor in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data), !Task.isCancelled else { return }
            self.artworkCache[urlString] = image
            self.updateNowPlaying(artwork: image)
        }
    }

    private func applyRate() {
        guard isPlaying else { return }
        player.rate = playbackSpeed
    }

    // MARK: - History

    private func recordHistory(for song: Song) {
        let artists = song.artists?.all?.compactMap { $0.name }.joined(separator: ", ") ?? ""
        let entry = SavedLibrary.SavedSong(
            id: song.id ?? "",
            title: song.displayName,
            description: artists,
            image: song.artworkURL ?? ""
        )
        let primaryArtist = song.artists?.primary?.first
        Preferences.shared.addRecentlyPlayed(entry, artistId: primaryArtist?.id, artistName: primaryArtist?.name)
    }
}
