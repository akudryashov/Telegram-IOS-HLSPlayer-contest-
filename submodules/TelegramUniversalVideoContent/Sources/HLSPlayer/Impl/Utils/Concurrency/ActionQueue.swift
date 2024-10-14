//
//  Created by qubasta on 23.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

final class ActionQueue {
    typealias Action = () -> Void

    private let queue: DispatchQueue
    private var actions = Atomic(HLSQueue<Action>())
    var paused: Bool = false {
        didSet {
            guard paused != oldValue else {
                return
            }
            commit()
        }
    }

    init(
        queue: DispatchQueue
    ) {
        self.queue = queue
    }

    func enqueue(_ action: @escaping Action) {
        var wasEmpty = false
        actions.mutate {
            wasEmpty = $0.isEmpty
            $0.enqueue(action)
        }

        if wasEmpty {
            commit()
        }
    }

    private func commit() {
        if paused { return }
        queue.async { [weak self] in
            guard let self else { return }
            let action = actions.mutate { $0.dequeue() }
            action?()
            commit()
        }
    }

    func removeAll() {
        actions.mutate { $0.removeAll() }
    }
}
