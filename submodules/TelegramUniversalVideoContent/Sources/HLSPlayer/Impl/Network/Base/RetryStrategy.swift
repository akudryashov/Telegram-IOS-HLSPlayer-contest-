//
//  Created by qubasta on 12.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

typealias RetryCallback = (TimeInterval?) -> Void

protocol RetryStrategy {
    var delay: TimeInterval? { get }

    func shouldRetry(response: URLResponse?, error: (any Error)?) -> Bool
}

final class SimpleRetryStrategy: RetryStrategy {
    private var retryCount: Int
    let delay: TimeInterval? = 1
    
    init(retryCount: Int = 3) {
        self.retryCount = retryCount
    }

    func shouldRetry(response _: URLResponse?, error _: (any Error)?) -> Bool {
        retryCount -= 1
        print("RETRY: \(retryCount)")
        return retryCount > 0
    }
}
