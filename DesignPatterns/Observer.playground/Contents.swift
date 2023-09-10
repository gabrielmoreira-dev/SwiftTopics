import Foundation


// MARK: - Initial Setup

enum State {
    case idle
    case playing(Item)
    case paused(Item)
}

struct Item {
    let title: String
}

protocol AudioPlaying: AnyObject {
    var state: State { get set }
    func play(_ item: Item)
    func pause()
    func stop()
    func stateDidChange()
}

extension AudioPlaying {
    func play(_ item: Item) {
        state = .playing(item)
    }

    func pause() {
        switch state {
        case .idle, .paused:
            break
        case .playing(let item):
            state = .paused(item)
        }
    }

    func stop() {
        state = .idle
    }
}


// MARK: - Implementation with NoticiationCenter API

final class AudioPlayerNC: AudioPlaying {
    private let notificationCenter: NotificationCenter
    var state = State.idle { didSet { stateDidChange() } }

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func stateDidChange() {
        switch state {
        case .idle:
            notificationCenter.post(name: .playbackStopped, object: nil)
        case .playing(let item):
            notificationCenter.post(name: .playbackStarted, object: item)
        case .paused(let item):
            notificationCenter.post(name: .playbackPaused, object: item)
        }
    }
}

extension Notification.Name {
    static var playbackStarted: Self { .init(rawValue: "AudioPlayer.playbackStarted") }
    static var playbackPaused: Self { .init(rawValue: "AudioPlayer.playbackPaused") }
    static var playbackStopped: Self { .init(rawValue: "AudioPlayer.playbackStopped") }
}

final class NowPlayingViewNC {
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        notificationCenter.addObserver(
            self,
            selector: #selector(playbackDidStart),
            name: .playbackStarted,
            object: nil
        )
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    @objc private func playbackDidStart(_ notification: Notification) {
        guard let item = notification.object as? Item else {
            return
        }
        print("Item started: \(item.title)")
    }
}

let audioPlayerNC = AudioPlayerNC()
let nowPlayingViewNC = NowPlayingViewNC()
audioPlayerNC.play(Item(title: "Track 1"))


// MARK: - Implementation with Observation Protocols

protocol AudioPlayerObserver: AnyObject {
    func audioPlayer(_ player: AudioPlayerOP, didStartPlaying item: Item)
    func audioPlayer(_ player: AudioPlayerOP, didPausePlaybackOf item: Item)
    func audioPlayerDidStop(_ player: AudioPlayerOP)
}

extension AudioPlayerObserver {
    func audioPlayer(_ player: AudioPlayerOP, didStartPlaying item: Item) {}
    func audioPlayer(_ player: AudioPlayerOP, didPausePlaybackOf item: Item) {}
    func audioPlayerDidStop(_ player: AudioPlayerOP) {}
}

final class AudioPlayerOP: AudioPlaying {
    private var observers: [ObjectIdentifier: ObservationWrapper] = [:]
    var state = State.idle { didSet { stateDidChange() } }

    func addObserver(_ observer: AudioPlayerObserver) {
        let id = ObjectIdentifier(observer)
        observers[id] = ObservationWrapper(observer: observer)
    }

    func removeObserver(_ observer: AudioPlayerObserver) {
        let id = ObjectIdentifier(observer)
        observers.removeValue(forKey: id)
    }

    func stateDidChange() {
        for (id, observerWrapper) in observers {
            guard let observer = observerWrapper.observer else {
                observers.removeValue(forKey: id)
                continue
            }
            switch state {
            case .idle:
                observer.audioPlayerDidStop(self)
            case .playing(let item):
                observer.audioPlayer(self, didStartPlaying: item)
            case .paused(let item):
                observer.audioPlayer(self, didPausePlaybackOf: item)
            }
        }
    }
}

private extension AudioPlayerOP {
    struct ObservationWrapper {
        weak var observer: AudioPlayerObserver?
    }
}

final class NowPlayingViewOP {
    private let audioPlayer: AudioPlayerOP

    init(audioPlayer: AudioPlayerOP) {
        self.audioPlayer = audioPlayer
        audioPlayer.addObserver(self)
    }
}

extension NowPlayingViewOP: AudioPlayerObserver {
    func audioPlayer(_ player: AudioPlayerOP, didStartPlaying item: Item) {
        print("Item started: \(item.title)")
    }
}

let audioPlayerOP = AudioPlayerOP()
let nowPlayingViewOP = NowPlayingViewOP(audioPlayer: audioPlayerOP)
audioPlayerOP.play(Item(title: "Track 2"))


// MARK: - Implementation with closures and Tokens

final class ObservationToken {
    private let cancelClosure: () -> Void

    init(cancelClosure: @escaping () -> Void) {
        self.cancelClosure = cancelClosure
    }

    func cancel() {
        cancelClosure()
    }
}

extension Dictionary where Key == UUID {
    mutating func insert(_ value: Value) -> UUID {
        let id = UUID()
        self[id] = value
        return id
    }
}

final class AudioPlayerCl: AudioPlaying {
    var state = State.idle { didSet { stateDidChange() } }

    private var observers = (
        started: [UUID: (AudioPlayerCl, Item) -> Void](),
        paused: [UUID: (AudioPlayerCl, Item) -> Void](),
        stopped: [UUID: (AudioPlayerCl) -> Void]()
    )

    @discardableResult
    func observePlaybackStarted(using closure: @escaping (AudioPlayerCl, Item) -> Void) -> ObservationToken {
        let id = observers.started.insert(closure)
        return ObservationToken { [weak self] in
            self?.observers.started.removeValue(forKey: id)
        }
    }

    @discardableResult
    func observePlaybackPaused(using closure: @escaping (AudioPlayerCl, Item) -> Void) -> ObservationToken {
        let id = observers.paused.insert(closure)
        return ObservationToken { [weak self] in
            self?.observers.paused.removeValue(forKey: id)
        }
    }

    @discardableResult
    func observePlaybackStopped(using closure: @escaping (AudioPlayerCl) -> Void) -> ObservationToken {
        let id = observers.stopped.insert(closure)
        return ObservationToken { [weak self] in
            self?.observers.stopped.removeValue(forKey: id)
        }

    }

    func stateDidChange() {
        switch state {
        case .idle:
            observers.stopped.values.forEach { closure in closure(self) }
        case .playing(let item):
            observers.started.values.forEach { closure in closure(self, item) }
        case .paused(let item):
            observers.paused.values.forEach { closure in closure(self, item) }
        }
    }
}

final class NowPlayingViewCl {
    private let audioPlayer: AudioPlayerCl
    private var observationToken: ObservationToken?

    init(audioPlayer: AudioPlayerCl) {
        self.audioPlayer = audioPlayer
        observationToken = audioPlayer.observePlaybackStarted { _, item in
            print("Item started: \(item.title)")
        }
    }

    deinit {
        observationToken?.cancel()
    }
}

let audioPlayerCl = AudioPlayerCl()
let nowPlayingViewCl = NowPlayingViewCl(audioPlayer: audioPlayerCl)
audioPlayerCl.play(Item(title: "Track 3"))
