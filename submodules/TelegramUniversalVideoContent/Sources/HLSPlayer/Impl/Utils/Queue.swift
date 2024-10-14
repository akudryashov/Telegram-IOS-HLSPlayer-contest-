//
//  Created by qubasta on 20.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

struct HLSQueue<T> {
    private var inStack = [T]()
    private var outStack = [T]()

    /// Пустая ли очередь
    public var isEmpty: Bool {
        inStack.isEmpty && outStack.isEmpty
    }

    /// Размер очереди
    public var count: Int {
        inStack.count + outStack.count
    }

    public mutating func enqueue(_ element: T) {
        inStack.append(element)
    }

    @discardableResult
    public mutating func dequeue() -> T? {
        transferElementsIfNeeded()
        return outStack.isEmpty ? nil : outStack.removeLast()
    }

    public var peek: T? {
        return outStack.last ?? inStack.first
    }

    /// Очистить очередь
    public mutating func removeAll() {
        outStack = []
        inStack = []
    }

    private mutating func transferElementsIfNeeded() {
        guard outStack.isEmpty else {
            return
        }
        outStack = inStack.reversed()
        inStack = []
    }
}
