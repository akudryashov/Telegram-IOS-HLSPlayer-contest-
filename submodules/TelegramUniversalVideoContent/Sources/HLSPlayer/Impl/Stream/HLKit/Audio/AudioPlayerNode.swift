@preconcurrency import AVFoundation
import Foundation

final class AudioPlayerNode {
    static let bufferCounts: Int = 10

    var currentTime: TimeInterval {
        if playerNode.isPlaying {
            guard
                let nodeTime = playerNode.lastRenderTime,
                let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
                return 0.0
            }
            //print("[AudioPlayerNode] playerTime: \(startAt?.seconds) + \(playerTime.seconds)")
            return (startAt?.seconds ?? 0) + playerTime.seconds
        }
        return (pausedTime ?? 0)
    }
    var soundTransform = SoundTransform() {
        didSet {
            soundTransform.apply(playerNode)
        }
    }

    var isPlaying: Bool {
        playerNode.isPlaying
    }
    private(set) var isRunning = false
    private let playerNode: AVAudioPlayerNode
    private var audioTime = AudioTime()
    private var startAt: AVAudioTime?
    private var pausedTime: TimeInterval?
    private var scheduledAudioBuffers: Int = 0 {
        didSet {
            guard isRunning, scheduledAudioBuffers == 0 else { return }

            GCD.onMainThread { [self] in
                if isRunning, scheduledAudioBuffers == 0 {
                    pause(reset: false)
                }
            }
        }
    }
    private weak var player: AudioPlayer?
    private(set) var format: AVAudioFormat? {
        didSet {
            guard format != oldValue else {
                return
            }
            let currentTime = self.currentTime
            player?.connect(self, format: nil)
            player?.connect(self, format: format)

            if oldValue.isSome {
                audioTime.reset()
                startAt = audioTime.makeTime(seconds: currentTime, sampleRate: format?.sampleRate)
                start()
            }
        }
    }

    init(player: AudioPlayer, playerNode: AVAudioPlayerNode) {
        self.player = player
        self.playerNode = playerNode
    }

    func enqueue(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        format = audioBuffer.format
        guard let audioBuffer = audioBuffer as? AVAudioPCMBuffer, let player, player.isConnected(self) else {
            return
        }
        guard startAt.isNone || when.seconds >= (startAt?.seconds ?? 0) else { return }

        scheduledAudioBuffers += 1
        if isRunning && !playerNode.isPlaying && Self.bufferCounts <= scheduledAudioBuffers {
            playerNode.play()
        }
        if !audioTime.hasAnchor {
            audioTime.anchor(startAt ?? playerNode.lastRenderTime ?? AVAudioTime(hostTime: 0))
        }
        audioTime.advanced(Int64(audioBuffer.frameLength))
        playerNode.scheduleBuffer(audioBuffer, at: audioTime.at, completionHandler: onCompleteSchedule)
        //print("[AudioPlayerNode][\(format?.sampleRate)] scheduleBuffer at:\(startAt?.seconds ?? 0) when: \(when.seconds)")
    }
    
    private func onCompleteSchedule() {
        scheduledAudioBuffers -= 1
    }

    func detach() {
        pause(reset: true)
        player?.detach(self)
    }
}

extension AudioPlayerNode: Runner {
    // MARK: AsyncRunner
    func start() {
        guard !isRunning else {
            return
        }
        if let format {
            player?.connect(self, format: format)
            if scheduledAudioBuffers >= Self.bufferCounts {
                playerNode.play()
            }
            pausedTime = startAt?.seconds
            print("[AudioPlayerNode][\(format.sampleRate)] start with \(startAt?.seconds ?? 0) \(scheduledAudioBuffers)")
        }
        isRunning = true
    }
    
    func pause(reset resetFlag: Bool) {
        guard isRunning else {
            return
        }
        print("[AudioPlayerNode][\(String(describing: format?.sampleRate))] paused with: \(startAt?.seconds ?? 0) on \(currentTime) with reset: \(resetFlag)")
        if playerNode.isPlaying {
            pausedTime = currentTime
            playerNode.pause()
            player?.pause()
        }
        if resetFlag {
            reset()
        }
        isRunning = false
    }

    func seek(to seconds: TimeInterval, reset resetFlag: Bool = true) {
        let time = audioTime.makeTime(seconds: seconds)
        print("[AudioPlayerNode][\(String(describing: format?.sampleRate))] seek to: \(currentTime) -> \(time?.seconds ?? 0) reset: \(resetFlag)")
        if resetFlag {
            reset()
        }

        startAt = time
        start()
    }

    private func reset() {
        //player?.stop()
        playerNode.stop()
        audioTime.reset()
        scheduledAudioBuffers = 0
    }
}

extension AudioPlayerNode: Hashable {
    // MARK: Hashable
    public static func == (lhs: AudioPlayerNode, rhs: AudioPlayerNode) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension AVAudioTime {
    var seconds: TimeInterval {
        TimeInterval(sampleTime) / sampleRate
    }
}
