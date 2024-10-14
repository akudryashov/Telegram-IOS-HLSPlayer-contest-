//
//  Created by qubasta on 06.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

struct HLSChunk: Equatable {
    var name: String? = nil

    var uri: String = ""
    var duration: TimeInterval = 0.0
    var startTime: TimeInterval = 0.0
}
