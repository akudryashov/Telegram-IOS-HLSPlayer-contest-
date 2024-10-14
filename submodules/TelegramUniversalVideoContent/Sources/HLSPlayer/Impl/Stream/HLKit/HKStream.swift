import AVFAudio
import AVFoundation
import CoreImage
import CoreMedia

/// The interface is the foundation of the RTMPStream and SRTStream.
protocol HKStream: AnyObject {
    /// Appends a CMSampleBuffer.
    /// - Parameters:
    ///   - sampleBuffer:The sample buffer to append.
    func stream(_ sampleBuffer: CMSampleBuffer)

    /// Attaches an audio player instance for playback.
    func attachAudioPlayer(_ audioPlayer: AudioPlayer?)

    /// Adds an output observer.
    func addOutput(_ obserber: some HKStreamOutput)

    /// Removes an output observer.
    func removeOutput(_ observer: some HKStreamOutput)
}
