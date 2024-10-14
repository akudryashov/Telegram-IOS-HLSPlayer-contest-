//
//  Created by qubasta on 06.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

public protocol Cancellable: AnyObject {
    func cancel()
}

extension URLSessionDataTask: Cancellable {}

final class AnyCancellable: Cancellable {
    private let cancelAction: () -> Void

    init(_ cancel: @escaping () -> Void = {}) {
        cancelAction = cancel
    }

    func cancel() {
        cancelAction()
    }
}
