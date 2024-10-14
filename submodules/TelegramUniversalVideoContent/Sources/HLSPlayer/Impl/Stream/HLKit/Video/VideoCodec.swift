import AVFoundation
import CoreFoundation
import VideoToolbox
#if canImport(UIKit)
import UIKit
#endif

// MARK: -
/**
 * The VideoCodec class provides methods for encode or decode for video.
 */
final class VideoCodec {
    static let defaultFrameRate: Float64 = 30
    static let frameInterval: Double = 0.0

    /// Specifies the settings for a VideoCodec.
    var settings: VideoCodecSettings = .default {
        didSet {
            let invalidateSession = settings.invalidateSession(oldValue)
            if invalidateSession {
                self.isInvalidateSession = invalidateSession
            } else {
                settings.apply(self, rhs: oldValue)
            }
        }
    }
    var frameInterval = VideoCodec.frameInterval
    let expectedFrameRate = VideoCodec.defaultFrameRate

    private(set) var isRunning: Bool = false
    private(set) var inputFormat: CMFormatDescription? {
        didSet {
            guard inputFormat != oldValue else {
                return
            }
            isInvalidateSession = true
            outputFormat = nil
        }
    }
    private(set) var session: (any VTSessionConvertible)? {
        didSet {
            oldValue?.invalidate()
            isInvalidateSession = false
        }
    }
    private(set) var outputFormat: CMFormatDescription?
    var outputStream: HLSSignal<TSBuffer> {
        outputStreamImpl
    }
    private var outputStreamImpl = DefaultSignal<TSBuffer>()
    private var isInvalidateSession = true
    private var queue: DispatchQueue

    init(queue: DispatchQueue = DispatchQueue(label: "com.hlsplayer.video.codec", qos: .userInitiated)) {
        self.queue = queue
    }

    func decode(_ buffer: TSBuffer) {
        queue.async {
            self.decodeImpl(buffer)
        }
    }

    private func decodeImpl(_ buffer: TSBuffer) {
        guard isRunning else { return }
        do {
            inputFormat = buffer.ptr.formatDescription
            if isInvalidateSession {
                if buffer.ptr.formatDescription?.isCompressed == true {
                    session = try VTSessionMode.decompression.makeSession(self)
                } else {
                    session = try VTSessionMode.compression.makeSession(self)
                }
            }
            guard let session else {
                return
            }
            try session.convert(buffer, completion: { [weak self] in
                self?.outputStreamImpl.send($0)
            })
        } catch {
            print("[VideoCoder] Error: \(error)")
        }
    }

    func imageBufferAttributes(_ mode: VTSessionMode) -> [NSString: AnyObject]? {
        switch mode {
        case .compression:
            var attributes: [NSString: AnyObject] = [:]
            if let mediaType = inputFormat?.mediaType {
                // Specify the pixel format of the uncompressed video.
                attributes[kCVPixelBufferPixelFormatTypeKey] = mediaType.rawValue as CFNumber
            }
            return attributes.isEmpty ? nil : attributes
        case .decompression:
            return [
                kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
                kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
            ]
        }
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    @objc
    private func applicationWillEnterForeground(_ notification: Notification) {
        isInvalidateSession = true
    }

    @objc
    private func didAudioSessionInterruption(_ notification: Notification) {
        guard
            let userInfo: [AnyHashable: Any] = notification.userInfo,
            let value: NSNumber = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber,
            let type = AVAudioSession.InterruptionType(rawValue: value.uintValue) else {
            return
        }
        switch type {
        case .ended:
            isInvalidateSession = true
        default:
            break
        }
    }
    #endif
}

extension VideoCodec: Runner {
    // MARK: Running
    func start() {
        guard !isRunning else {
            return
        }
        isRunning = true
    }

    func pause(reset: Bool) {
        guard isRunning else {
            return
        }
        isRunning = !reset
    }

    func seek(to time: TimeInterval) {
        start()
    }
}
