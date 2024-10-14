//
//  Created by qubasta on 13.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

public enum PlaybackEvent {
    case play
    case pause
    case reset
    case seekTo(TimeInterval)
}

public protocol Playback {
    var eventSignal: HLSSignal<PlaybackEvent> { get }
    var playTimeSignal: HLSSignal<TimeInterval> { get }
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var loadingOptions: [LoadingStrategyOption] { get }

    var volume: Float { get set }

    func play()
    func pause()
    func load(url: URL)
    func seekTo(time: TimeInterval)

    func setLoadingStrategy(_ loadingStrategy: LoadingStrategy)
}

final class PlaybackController: Playback {
    struct PlayableInfo {
        private let playTimeSignal: DefaultSignal<TimeInterval>

        let url: URL
        private(set) var currentTime: TimeInterval = 0
        var duration: TimeInterval = 0
        private let updateTime: (TimeInterval) -> Void

        init(
            playTimeSignal: DefaultSignal<TimeInterval>,
            url: URL,
            updateTime: @escaping (TimeInterval) -> Void
        ) {
            self.playTimeSignal = playTimeSignal
            self.url = url
            self.updateTime = updateTime
        }

        mutating func setCurrentTime(_ time: TimeInterval) {
            currentTime = max(0, min(duration, time))
            updateTime(currentTime)
            GCD.onMainThread { [self, currentTime] in
                playTimeSignal.send(currentTime)
            }
        }
    }

    private let loadingController: LoadingController
    private var cancellables = CancellableBag()

    var currentItem: PlayableInfo?
    var isPlaying: Bool

    var loadingOptions: [LoadingStrategyOption] {
        loadingController.loadingOptions
    }
    var volume: Float {
        get {
            hlk.soundTransform?.volume ?? 0
        }
        set {
            hlk.soundTransform = SoundTransform(volume: newValue)
        }
    }
    @Atomic(0)
    var currentTime: TimeInterval
    @Atomic(0)
    var duration: TimeInterval
    var playTimeSignal: HLSSignal<TimeInterval> {
        playTimeSignalImpl
    }
    var eventSignal: HLSSignal<PlaybackEvent> {
        eventSignalImpl
    }
    private let eventSignalImpl = DefaultSignal<PlaybackEvent>()
    private let playTimeSignalImpl = DefaultSignal<TimeInterval>()
    private let hlk: HLKitStreamWrapper

    init(
        loadingController: LoadingController,
        hlk: HLKitStreamWrapper
    ) {
        self.loadingController = loadingController
        self.hlk = hlk
        isPlaying = false
        currentItem = nil
        subscribe()
    }

    func setLoadingStrategy(_ loadingStrategy: LoadingStrategy) {
        guard loadingController.strategy != loadingStrategy else { return }
        reset()
        loadingController.setLoadingStrategy(to: loadingStrategy)
    }

    private func subscribe() {
        loadingController.state.sink { [weak self] in
            guard let self else { return }
                switch $0 {
                case .empty:
                    break //TODO: send Error
                case .loading:
                    break //TODO: send Loading
                case let .loaded(variant):
                    currentItem?.duration = variant.full!.fullDuration
                    duration = variant.full!.fullDuration
                    play()
            }
        }.store(in: &cancellables)
    }

    func load(url: URL) {
        guard currentItem?.url != url else {
            print("[Playback] \(url) is already loaded")
            return
        }
        if isPlaying {
            reset()
        }

        currentItem = PlayableInfo(
            playTimeSignal: playTimeSignalImpl,
            url: url,
            updateTime: { [unowned self] in
                currentTime = $0
            }
        )
        loadingController.startLoading(url: url)
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        eventSignalImpl.send(.play)
    }

    func seekTo(time: TimeInterval) {
        guard currentItem.isSome else { return }
        currentItem?.setCurrentTime(time)
        eventSignalImpl.send(.seekTo(time))
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        eventSignalImpl.send(.pause)
    }

    private func reset() {
        isPlaying = false
        eventSignalImpl.send(.reset)
    }
}
