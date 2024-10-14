import AVFoundation
import Foundation

/// A helper class for interoperating between AVAudioTime and CMTime.
/// Conversion fails without hostTime on the AVAudioTime side, and cannot be saved with AVAssetWriter.
final class AudioTime {
    var at: AVAudioTime {
        let now = AVAudioTime(sampleTime: sampleTime, atRate: sampleRate)
        guard let anchorTime else {
            return now
        }
        return now.extrapolateTime(fromAnchor: anchorTime) ?? now
    }

    var hasAnchor: Bool {
        anchorTime != nil
    }

    private var anchorTime: AVAudioTime?
    private(set) var sampleRate: Double = 0.0
    private(set) var sampleTime: AVAudioFramePosition = 0

    func advanced(_ count: AVAudioFramePosition) {
        sampleTime += count
    }

    func anchor(_ time: CMTime, sampleRate: Double) {
        guard anchorTime == nil else {
            return
        }
        self.sampleRate = sampleRate
        if time.timescale == Int32(sampleRate) {
            sampleTime = time.value
        } else {
            // ReplayKit .appAudio
            sampleTime = Int64(Double(time.value) * sampleRate / Double(time.timescale))
        }
        anchorTime = .init(hostTime: AVAudioTime.hostTime(forSeconds: time.seconds), sampleTime: sampleTime, atRate: sampleRate)
    }

    func anchor(_ time: AVAudioTime) {
        guard anchorTime == nil else {
            return
        }
        sampleRate = time.sampleRate
        sampleTime = 0
        anchorTime = time
        print("[AudioPlayerNode] sets anchor: \(time.seconds) \(time.sampleRate)")
    }

    func makeTime(seconds: TimeInterval, sampleRate ref: Double? = nil) -> AVAudioTime? {
        let sampleRate = ref ?? self.sampleRate
        guard sampleRate > 0 else {
            return nil
        }

        return AVAudioTime(
            sampleTime: AVAudioFramePosition(floor(seconds * sampleRate)),
            atRate: sampleRate
        )
    }

    func reset() {
        //sampleRate = 0.0
        sampleTime = 0
        anchorTime = nil
    }
}
