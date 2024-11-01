import AVFoundation
import CoreMedia
import Foundation

/// A delegate protocol your app implements to receive capture stream output events.
protocol HKStreamOutput: AnyObject, Sendable {
    /// Tells the receiver to a video buffer outgoing.
    func stream(_ stream: some HKStream, didOutput video: CMSampleBuffer)
}
