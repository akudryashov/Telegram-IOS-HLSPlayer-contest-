import Accelerate
import AVFoundation
import CoreMedia

#if hasAttribute(retroactive)
extension CMSampleBuffer: @retroactive @unchecked Sendable {}
#else
extension CMSampleBuffer: @unchecked Sendable {}
#endif

extension CMSampleBuffer {
    @inlinable @inline(__always) var isNotSync: Bool {
        get {
            guard let sampleAttachments, CFArrayGetCount(sampleAttachments) > 0 else {
                return false
            }
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(sampleAttachments, 0), to: CFMutableDictionary.self)
            let value = CFDictionaryGetValue(dict, unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self))
            return value != nil
        }
        set {
            guard let sampleAttachments, CFArrayGetCount(sampleAttachments) > 0 else {
                return
            }
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(sampleAttachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dict,
                unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self),
                unsafeBitCast(newValue ? kCFBooleanTrue : kCFBooleanFalse, to: UnsafeRawPointer.self)
            )
        }
    }

    @inlinable @inline(__always) var formatDescription: CMFormatDescription? {
        CMSampleBufferGetFormatDescription(self)
    }

    @inlinable var sampleAttachments: CFArray? {
        CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true)
    }

    var mediaType: CMSampleBufferMediaType? {
        formatDescription?.mediaType
    }

    var presentationTimeStamp: CMTime {
        CMSampleBufferGetPresentationTimeStamp(self)
    }

    var outputPresentationTimeStamp: CMTime {
        CMSampleBufferGetOutputPresentationTimeStamp(self)
    }

    var duration: CMTime {
        CMSampleBufferGetDuration(self)
    }
    
    var numSamples: CMItemCount {
        CMSampleBufferGetNumSamples(self)
    }
    
    var dataBuffer: CMBlockBuffer? {
        CMSampleBufferGetDataBuffer(self)
    }

    var imageBytes: Data? {
        guard let imageBuffer else {
            return nil
        }
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let src_buff = CVPixelBufferGetBaseAddress(imageBuffer)
        let data = NSData(bytes: src_buff, length: bytesPerRow * height)
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return data as Data
    }

    var imageBuffer: CVImageBuffer? {
        CMSampleBufferGetImageBuffer(self)
    }

    var decodeTimeStamp: CMTime {
        CMSampleBufferGetDecodeTimeStamp(self)
    }
}

extension CMFormatDescription {
    func forEachParamterSetH264(_ body: (Data) -> Void) {
        var count = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            self,
            parameterSetIndex: 0,
            parameterSetPointerOut: nil,
            parameterSetSizeOut: nil,
            parameterSetCountOut: &count,
            nalUnitHeaderLengthOut: nil
        )

        for i in 0 ..< count {
            var data = Data()
            var parameterSetPointer: UnsafePointer<UInt8>!
            var parameterSetLength = 0
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                self,
                parameterSetIndex: i,
                parameterSetPointerOut: &parameterSetPointer,
                parameterSetSizeOut: &parameterSetLength,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil
            )

            data.append(parameterSetPointer, count: parameterSetLength)
            body(data)
        }
    }

    func forEachParamterSetHEVC(_ body: (Data) -> Void) {
        var count = 0
        CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
            self,
            parameterSetIndex: 0,
            parameterSetPointerOut: nil,
            parameterSetSizeOut: nil,
            parameterSetCountOut: &count,
            nalUnitHeaderLengthOut: nil
        )

        for i in 0 ..< count {
            var data = Data()
            var parameterSetPointer: UnsafePointer<UInt8>!
            var parameterSetLength = 0
            CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
                self,
                parameterSetIndex: i,
                parameterSetPointerOut: &parameterSetPointer,
                parameterSetSizeOut: &parameterSetLength,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil
            )

            data.append(parameterSetPointer, count: parameterSetLength)
            body(data)
        }
    }
}

extension CMAudioFormatDescription  {
    var audioStreamBasicDescription: AudioStreamBasicDescription? {
        unsafeBitCast(CMAudioFormatDescriptionGetStreamBasicDescription(self), to: AudioStreamBasicDescription.self)
    }
}

extension CMBlockBuffer {
    var dataLength: Int {
        CMBlockBufferGetDataLength(self)
    }
}
