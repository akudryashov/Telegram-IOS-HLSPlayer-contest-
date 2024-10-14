//
//  Created by qubasta on 08.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

protocol HLSChunkLoader: AnyObject {
    func loadChunk(
        configURL: URL,
        chunk: HLSChunk,
        completion: @escaping (Result<Data, Error>) -> Void
    )
}
