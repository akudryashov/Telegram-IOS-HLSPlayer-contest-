@preconcurrency import AVFoundation

/// An object that provides the interface to control audio playback.
final class AudioPlayer {
    private var connected: [AudioPlayerNode: AVAudioFormat] = [:]
    private let audioEngine: AVAudioEngine
    private var playerNodes: [AudioPlayerNode: AVAudioPlayerNode] = [:]

    /// Create an audio player object.
    init(audioEngine: AVAudioEngine) {
        self.audioEngine = audioEngine
    }

    func isConnected(_ playerNode: AudioPlayerNode) -> Bool {
        connected[playerNode].isSome
    }

    func node(format: AVAudioFormat) -> AudioPlayerNode? {
        connected.first(where: { format == $0.value })?.key
    }

    func connect(_ playerNode: AudioPlayerNode, format: AVAudioFormat?) {
        guard let avPlayerNode = playerNodes[playerNode] else {
            return
        }
        if let format {
            audioEngine.connect(avPlayerNode, to: audioEngine.mainMixerNode, format: format)
            if !audioEngine.isRunning {
                try? audioEngine.start()
            }
            connected[playerNode] = format
        } else {
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            //audioEngine.disconnectNodeOutput(avPlayerNode)
            connected[playerNode] = nil
        }
    }

    func detach(_ playerNode: AudioPlayerNode) {
        if let playerNode = playerNodes[playerNode] {
            audioEngine.detach(playerNode)
        }
        playerNodes[playerNode] = nil
    }

    func makePlayerNode() -> AudioPlayerNode {
        let avAudioPlayerNode = AVAudioPlayerNode()
        audioEngine.attach(avAudioPlayerNode)
        let playerNode = AudioPlayerNode(player: self, playerNode: avAudioPlayerNode)
        playerNodes[playerNode] = avAudioPlayerNode
        return playerNode
    }

    func pause() {
        audioEngine.pause()
    }

    func stop() {
        audioEngine.stop()
    }
}
