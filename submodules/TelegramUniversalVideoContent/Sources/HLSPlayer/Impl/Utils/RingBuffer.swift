//
//  Created by qubasta on 20.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

struct RingBuffer<Element> {
    private var head: Int = 0
    private var tail: Int = 0
    private(set) var count: Int = 0
    private let capacity: Int
    private var elements: [Element?]

    var isEmpty: Bool { count == 0 }

    init(capacity: Int) {
        self.capacity = capacity
        self.elements = .init(repeating: nil, count: capacity)
    }

    var first: Element? {
        guard head != tail else { return nil }
        return elements[head]
    }

    mutating func enqueue(_ element: Element) {
        elements[tail] = element
        moveTail()
    }

    func at(index: Int) -> Element? {
        guard index < count || index < 0 else { return nil }
        let offset = (head + index) % elements.count
        return elements[offset]
    }

    mutating func dequeue() -> Element? {
        guard head != tail || count == capacity else { return nil }
        guard let element = elements[head] else { return nil }
        moveHead()
        count -= 1
        return element
    }

    mutating func moveHead() {
        head += 1
        head %= elements.count
    }

    mutating func moveTail() {
        if tail == head && count == capacity {
            moveHead()
        } else {
            count += 1
        }
        tail += 1
        tail %= elements.count
    }

    mutating func clear() {
        head = 0
        tail = 0
        count = 0
    }
}
