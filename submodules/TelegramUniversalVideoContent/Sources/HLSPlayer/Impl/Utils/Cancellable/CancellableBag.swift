//
//  Created by qubasta on 13.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

final class CancellableBag {
    private var inputs: [Cancellable] = []

    deinit {
        removeAll()
    }

    func append(_ input: Cancellable) {
        inputs.append(input)
    }

    func removeAll() {
        inputs.forEach {
            $0.cancel()
        }
        inputs.removeAll()
    }
}

extension Cancellable {
    func store(in bag: inout CancellableBag) {
        bag.append(self)
    }
}
