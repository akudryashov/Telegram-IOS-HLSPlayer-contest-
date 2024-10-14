import Foundation
import VideoToolbox

extension VTDecompressionSession: VTSessionConvertible {
    static let defaultDecodeFlags: VTDecodeFrameFlags = [
        ._EnableAsynchronousDecompression,
        ._EnableTemporalProcessing
    ]

    @inline(__always)
    func convert(_ buffer: TSBuffer, completion: @escaping (TSBuffer) -> Void) throws {
        var flagsOut: VTDecodeInfoFlags = []
        var _: VTEncodeInfoFlags = []
        let status = VTDecompressionSessionDecodeFrame(
            self,
            sampleBuffer: buffer.ptr,
            flags: Self.defaultDecodeFlags,
            infoFlagsOut: &flagsOut,
            outputHandler: { status, _, imageBuffer, presentationTimeStamp, duration in
                guard let imageBuffer else {
                    return
                }
                var status = noErr
                var outputFormat: CMFormatDescription?
                status = CMVideoFormatDescriptionCreateForImageBuffer(
                    allocator: kCFAllocatorDefault,
                    imageBuffer: imageBuffer,
                    formatDescriptionOut: &outputFormat
                )
                guard let outputFormat, status == noErr else {
                    return
                }
                var timingInfo = CMSampleTimingInfo(
                    duration: duration,
                    presentationTimeStamp: presentationTimeStamp - buffer.timeCorrection,
                    decodeTimeStamp: .invalid
                )
                var sampleBuffer: CMSampleBuffer?
                status = CMSampleBufferCreateForImageBuffer(
                    allocator: kCFAllocatorDefault,
                    imageBuffer: imageBuffer,
                    dataReady: true,
                    makeDataReadyCallback: nil,
                    refcon: nil,
                    formatDescription: outputFormat,
                    sampleTiming: &timingInfo,
                    sampleBufferOut: &sampleBuffer
                )
                if let sampleBuffer {
                    completion(TSBuffer(
                        ptr: sampleBuffer,
                        timeCorrection: .zero,
                        pid: buffer.pid,
                        isSync: buffer.isSync
                    ))
                }
            }
        )
        if status != noErr {
            throw VTSessionError.failedToConvert(status: status)
        }
    }

    func invalidate() {
        VTDecompressionSessionInvalidate(self)
    }
}
