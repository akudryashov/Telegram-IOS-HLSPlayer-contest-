//
//  Created by qubasta on 24.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import CoreMedia

struct TSBuffer {
    let ptr: CMSampleBuffer
    let timeCorrection: CMTime
    let pid: UInt16
    let isSync: Bool

    var pts: CMTime {
        ptr.presentationTimeStamp - timeCorrection
    }
}
