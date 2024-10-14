//
//  Created by qubasta on 26.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

protocol HLSStreamLoader: Runner {
    var configVariant: HLSVariant.Full? { get }
    var output: HLSSignal<TSBuffer> { get }

    func seek(to time: TimeInterval, completion: @escaping () -> Void)
}
