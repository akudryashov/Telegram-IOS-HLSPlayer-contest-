//
//  Created by qubasta on 13.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

enum GCD {
    static func after(
        delay: TimeInterval,
        queue: DispatchQueue = .main,
        execute block: @escaping () -> Void
    ) -> Cancellable {
        let workItem = DispatchWorkItem(block: block)
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
        return workItem
    }
    
    static func onMainThread(
        _ block: @escaping () -> Void
    ) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

extension DispatchQueue {
    func asyncTask(
        execute block: @escaping () -> Void
    ) -> Cancellable {
        let workItem = DispatchWorkItem(block: block)
        async(execute: workItem)
        return workItem
    }
}

extension DispatchWorkItem: Cancellable {}
