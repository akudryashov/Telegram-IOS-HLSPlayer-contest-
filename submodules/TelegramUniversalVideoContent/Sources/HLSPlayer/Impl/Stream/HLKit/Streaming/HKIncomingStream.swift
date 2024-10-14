@preconcurrency import AVFoundation
import Foundation

/// An actor that provides a stream playback feature.
final class HKIncomingStream {
    var isAllowsToRead: Bool {
        mediaLink.isAllowsToRead
    }

    private(set) var isRunning: Bool = false
    /// The sound transform value control.
    var soundTransform: SoundTransform? {
        get {
            audioPlayerNode?.soundTransform
        }
        set {
            audioPlayerNode?.soundTransform = newValue ?? SoundTransform()
        }
    }
    private lazy var audioCodec = AudioCodec()
    private lazy var videoCodec = VideoCodec()
    private lazy var mediaLink = MediaLink()

    private weak var stream: (any HKStream)?
    private var audioPlayerNode: AudioPlayerNode?
    private var cancellables = CancellableBag()
    var waitingForSync: Bool = false {
        didSet {
            if waitingForSync {
                audioPlayerNode?.pause(reset: true)
            }
        }
    }

    init(_ stream: some HKStream) {
        self.stream = stream

        audioCodec.outputStream.sink { [weak self] audio in
            self?.mediaLink.enqueue(audio.0, when: audio.1)
        }.store(in: &cancellables)
        videoCodec.outputStream.sink { [weak self] in
            self?.mediaLink.enqueue($0)
        }.store(in: &cancellables)
        
        mediaLink.bufferSignal.sink { [weak self] in
            guard let self, isRunning else { return }
            self.stream?.stream($0.ptr)
        }.store(in: &cancellables)
    }

    func decode(_ buffer: TSBuffer) {
        guard isRunning else {
            return
        }
        if waitingForSync {
            waitingForSync = false
            seek(to: buffer.pts.seconds)
        }
        switch buffer.ptr.mediaType {
        case .audio:
            audioCodec.decode(buffer)
        case .video:
            videoCodec.decode(buffer)
        default:
            break
        }
    }

    /// Attaches an audio player.
    func attachAudioPlayer(_ audioPlayer: AudioPlayer?) {
        audioPlayerNode?.detach()
        audioPlayerNode = audioPlayer?.makePlayerNode()
        mediaLink.audioPlayerNode = audioPlayerNode
    }
}

extension HKIncomingStream: Runner {
    // MARK: Runner
    func start() {
        guard !isRunning else {
            return
        }
        isRunning = true
        if !waitingForSync {
            mediaLink.start()
            videoCodec.start()
            audioCodec.start()
            audioPlayerNode?.start()
        }
    }

    func pause(reset: Bool) {
        guard isRunning else {
            return
        }
        videoCodec.pause(reset: reset)
        audioCodec.pause(reset: reset)
        mediaLink.pause(reset: reset)
        audioPlayerNode?.pause(reset: reset)
        isRunning = false
    }

    func seek(to time: TimeInterval) {
        videoCodec.seek(to: time)
        audioCodec.seek(to: time)

        mediaLink.seek(to: time)
        audioPlayerNode?.seek(to: time)
    }
}
