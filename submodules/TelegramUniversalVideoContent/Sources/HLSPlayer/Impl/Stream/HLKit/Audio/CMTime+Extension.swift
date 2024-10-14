import AVFoundation
import Foundation

extension CMTime {
    //static let zero = CMTime(seconds: 0, preferredTimescale: CMTimeScale(TSTimestamp.resolution))

    func makeAudioTime() -> AVAudioTime {
        return .init(sampleTime: value, atRate: Double(timescale))
    }
}
