//
//  Created by qubasta on 06.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

enum HLSVariant: Equatable {
    struct Full: Equatable {
        let additionalInfo: AdditionalInfo

        let version: Int?
        let targetDuration: TimeInterval
        var fullDuration: TimeInterval {
            guard let last = chunks.last else { return 0 }
            return last.startTime + last.duration
        }

        let chunks: [HLSChunk]
    }
    struct AdditionalInfo: Equatable {
        let name: String
        let bandwidth: Int
        let codecs: [String]
        let url: URL
    }

    case ref(AdditionalInfo)
    case full(Full)

    var additionalInfo: AdditionalInfo {
        switch self {
        case let .ref(info):
            info
        case let .full(full):
            full.additionalInfo
        }
    }

    var full: Full? {
        switch self {
        case .ref:
            nil
        case let .full(full):
            full
        }
    }
}

