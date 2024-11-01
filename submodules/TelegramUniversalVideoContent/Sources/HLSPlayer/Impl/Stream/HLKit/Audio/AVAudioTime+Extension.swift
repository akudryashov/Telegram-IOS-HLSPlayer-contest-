import AVFoundation
import CoreMedia
import Foundation

extension AVAudioTime {
    func makeCMTime() -> CMTime {
        return .init(seconds: AVAudioTime.seconds(forHostTime: hostTime), preferredTimescale: 1000000000)
    }
}
