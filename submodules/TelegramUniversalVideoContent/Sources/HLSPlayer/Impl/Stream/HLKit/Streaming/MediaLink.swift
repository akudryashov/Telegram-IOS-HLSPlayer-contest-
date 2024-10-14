import CoreMedia
import AVFAudio
import Foundation
import QuartzCore

final class MediaLink {
    private let capacity = 40
    var bufferSignal: HLSSignal<TSBuffer> {
        bufferSignalImpl
    }
    var isAllowsToRead: Bool {
        storage.value.count < capacity
    }

    private var bufferSignalImpl = DefaultSignal<TSBuffer>()
    private(set) var isRunning = false
    private lazy var storage = Atomic(Heap<TSBuffer>(compare: { $0.pts < $1.pts }))
    private lazy var audioQueue = Atomic(HLSQueue<(AVAudioBuffer, AVAudioTime)>())
    private var maxKnownPts: CMTime = .invalid
    private lazy var displayLink = DisplayLinkChoreographer()
    private var displayLinkSub: Cancellable?
    weak var audioPlayerNode: AudioPlayerNode?

    private let garbageQueue: DispatchQueue = .global()

    func enqueue(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        if audioPlayerNode?.format != audioBuffer.format, audioPlayerNode?.format.isSome ?? false {
            audioQueue.mutate { $0.enqueue((audioBuffer, when))}
        } else {
            audioPlayerNode?.enqueue(audioBuffer, when: when)
        }
    }

    func unloadQueueIfNeeded() {
        if let audioPlayerNode, !audioPlayerNode.isPlaying, isRunning, let format = audioQueue.value.peek?.0.format {
            print("[MediaLink] unloads queue with format \(format)")
            while let peek = audioQueue.value.peek, peek.0.format == format {
                audioPlayerNode.enqueue(peek.0, when: peek.1)
                _ = audioQueue.mutate { $0.dequeue() }
            }
        }
    }

    func enqueue(_ sampleBuffer: TSBuffer) {
        let pts = sampleBuffer.pts
        if pts.seconds > maxKnownPts.seconds || !maxKnownPts.isValid {
            maxKnownPts = pts
        }
        storage.mutate { $0.enqueue(sampleBuffer) }
    }
}

extension MediaLink: Runner {
    // MARK: Runner
    func start() {
        guard !isRunning else {
            return
        }
        isRunning = true
        displayLink.start()
        displayLinkSub?.cancel()
        displayLinkSub = displayLink.updateFrames.sink { [weak self] linkTime in
            guard let self, isRunning else {
                return
            }
            let currentTime = audioPlayerNode?.currentTime ?? linkTime
            var frameCount = 0
            while !storage.value.isEmpty {
                guard let first = storage.value.peek() else {
                    break
                }
                unloadQueueIfNeeded()
                let frameTime = first.pts.seconds
                if frameTime <= currentTime {
                    bufferSignalImpl.send(first)
                    frameCount += 1
                    storage.mutate {
                        let frame = $0.dequeue()
                        self.garbageQueue.async { _ = frame } // Just kill from another thread
                    }
                    //print("[MediaLink] showFrame: \(first.isSync) \(frameTime) <= \(currentTime)")
                } else {
                    //print("[MediaLink] droppedFrame: \(frameTime) > \(currentTime)")
                    if 2 < frameCount {
                        print("[MediaLink] droppedFrame: \(frameCount)")
                    }
                    return
                }
            }
        }
    }

    func pause(reset resetFlag: Bool) {
        guard isRunning else {
            return
        }
        displayLinkSub?.cancel()
        displayLink.pause(reset: resetFlag)
        isRunning = false
        if resetFlag {
            reset()
        }
    }

    func seek(to time: TimeInterval) {
        reset()
        start()
    }

    private func reset() {
        audioQueue.mutate { queue in
            queue.removeAll()
        }
        storage.mutate { heap in
            let prevStorage = heap
            heap = .init(compare: { $0.pts.seconds < $1.pts.seconds })
            garbageQueue.async {
                prevStorage.removeAll()
            }
        }
    }
}
