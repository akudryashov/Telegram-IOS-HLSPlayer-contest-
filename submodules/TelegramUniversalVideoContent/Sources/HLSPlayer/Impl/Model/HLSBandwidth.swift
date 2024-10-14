//
//  Created by qubasta on 21.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

enum HLSBandwidth {
    case p240, p380, p480, p720, p1080

    var value: Int {
        switch self {
        case .p240: return 246_440
        case .p380: return 460_560
        case .p480: return 836_280
        case .p720: return 2_149_280
        case .p1080: return 6_221_600
        }
    }
}
