//
//  Created by qubasta on 12.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import AVFoundation

final class HLKitStreamWrapper: HKStream {
    enum HKStreamState: Int, Sendable {
        case idle
        case playing
    }

    var soundTransform: SoundTransform? {
        get {
            incoming.soundTransform
        }
        set {
            incoming.soundTransform = newValue ?? SoundTransform()
        }
    }
    private lazy var incoming = HKIncomingStream(self)
    private var outputs: [any HKStreamOutput] = []
    private var cancellables = CancellableBag()
    private weak var playbackController: PlaybackController?
    weak var loader: HLSStreamLoader? {
        didSet {
            loader?.output.sink { [weak self] in
                self?.onBuffer($0)
            }.store(in: &cancellables)
        }
    }

    private var shouldStartOnLoader: Bool = false
    var currentTime: TimeInterval? {
        playbackController?.currentItem?.currentTime
    }

    var readyState: HKStreamState = .idle

    func attachPlaybackController(_ playbackController: PlaybackController) {
        cancellables.removeAll()
        self.playbackController = playbackController
        playbackController.eventSignal.sink { [weak self] in
            guard let self else { return }
            switch $0 {
            case .play:
                play()
            case .pause:
                pause(reset: false)
            case .reset:
                pause(reset: true)
            case let .seekTo(time):
                seek(to: time)
            }
        }.store(in: &cancellables)
    }

    func attachAudioPlayer(_ audioPlayer: AudioPlayer?) {
        incoming.attachAudioPlayer(audioPlayer)
    }

    func onBuffer(_ buffer: TSBuffer) {
        if readyState == .idle {
            if shouldStartOnLoader {
                shouldStartOnLoader = false
                play()
            }
        }
        incoming.decode(buffer)
    }

    private func play() {
        print("[HLKStreamWrapper] Start playing")
        incoming.start()
        readyState = .playing
        if let loader, !loader.isRunning {
            loader.start()
        }
    }

    private func pause(reset: Bool) {
        print("[HLKStreamWrapper] Pause playing reset:\(reset)")
        loader?.pause(reset: reset)
        guard readyState == .playing else {
            return
        }
        incoming.pause(reset: reset)
        readyState = .idle
    }

    private func seek(to time: TimeInterval) {
        print("[HLKStreamWrapper] Seek to \(time)")
        if readyState == .playing {
            shouldStartOnLoader = true
            pause(reset: true)
        }
        incoming.waitingForSync = true
        loader?.seek(to: time, completion: { [weak self] in
            guard let self else { return }
            if shouldStartOnLoader {
                loader?.start()
            }
        })
    }

    func addOutput(_ observer: some HKStreamOutput) {
        guard !outputs.contains(where: { $0 === observer }) else {
            return
        }
        outputs.append(observer)
    }

    func removeOutput(_ observer: some HKStreamOutput) {
        if let index = outputs.firstIndex(where: { $0 === observer }) {
            outputs.remove(at: index)
        }
    }

    func stream(_ sampleBuffer: CMSampleBuffer) {
        guard readyState == .playing else {
            return
        }
        playbackController?.currentItem?.setCurrentTime(sampleBuffer.presentationTimeStamp.seconds)

        switch sampleBuffer.formatDescription?.mediaType {
        case .video:
            if sampleBuffer.formatDescription?.isCompressed == true {
                print("ERROR: compressed video not supported")
            } else {
                outputs.forEach { $0.stream(self, didOutput: sampleBuffer) }
            }
        default:
            break
        }
    }
}
