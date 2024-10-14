import Foundation
import VideoToolbox

extension VTCompressionSession {
    func prepareToEncodeFrames() -> OSStatus {
        VTCompressionSessionPrepareToEncodeFrames(self)
    }
}

extension VTCompressionSession: VTSessionConvertible {
    @inline(__always)
    func convert(_ buffer: TSBuffer, completion: @escaping (TSBuffer) -> Void) throws {
        guard let imageBuffer = buffer.ptr.imageBuffer else {
            return
        }
        var flags: VTEncodeInfoFlags = []
        let status = VTCompressionSessionEncodeFrame(
            self,
            imageBuffer: imageBuffer,
            presentationTimeStamp: buffer.pts,
            duration: buffer.ptr.duration,
            frameProperties: nil,
            infoFlagsOut: &flags,
            outputHandler: { _, _, sampleBuffer in
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
        VTCompressionSessionInvalidate(self)
    }
}
