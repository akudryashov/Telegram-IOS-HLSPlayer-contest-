//
//  Created by qubasta on 13.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import CoreMedia

enum CMSampleBufferMediaType: RawRepresentable {
    init?(rawValue: FourCharCode) {
        switch rawValue {
        case kCMMediaType_Audio:
            self = .audio
        case kCMMediaType_Video:
            self = .video
        default:
            print("[Error] unknown CMSampleBufferMediaType: \(rawValue.toString())")
            return nil
        }
    }
    
    case audio
    case video

    var rawValue: CMMediaType {
        switch self {
        case .audio:
            return kCMMediaType_Audio
        case .video:
            return kCMMediaType_Video
        }
    }
}

enum CMSampleBufferMediaSubType: RawRepresentable {
    case aac
    case linearPCM
    case hevc
    case h264
    
    var rawValue: FourCharCode {
        switch self {
        case .linearPCM:
            return kAudioFormatLinearPCM
        case .aac:
            return kAudioFormatMPEG4AAC
        case .hevc:
            return kCMVideoCodecType_HEVC
        case .h264:
            return kCMVideoCodecType_H264
        }
    }

    init?(rawValue: FourCharCode) {
        switch rawValue {
        case kAudioFormatLinearPCM:
            self = .linearPCM
        case kAudioFormatMPEG4AAC:
            self = .aac
        case kCMVideoCodecType_HEVC:
            self = .hevc
        case kCMVideoCodecType_H264:
            self = .h264
        default:
            print("[Error] unknown CMSampleBufferMediaSubType: \(rawValue.toString())")
            return nil
        }
    }
}

extension CMFormatDescription {
    var mediaType: CMSampleBufferMediaType? {
        CMSampleBufferMediaType(rawValue: CMFormatDescriptionGetMediaType(self))
    }

    var mediaSubType: CMSampleBufferMediaSubType? {
        CMSampleBufferMediaSubType(rawValue: CMFormatDescriptionGetMediaSubType(self))
    }
}

extension FourCharCode {
    func toString() -> String {
        let n = Int(self)
        var s: String = String(UnicodeScalar((n >> 24) & 255)!)
        s.append(String(UnicodeScalar((n >> 16) & 255)!))
        s.append(String(UnicodeScalar((n >> 8) & 255)!))
        s.append(String(UnicodeScalar(n & 255)!))
        return s
    }
}
