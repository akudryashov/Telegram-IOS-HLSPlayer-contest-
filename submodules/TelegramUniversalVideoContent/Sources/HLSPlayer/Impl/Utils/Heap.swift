//
//  Created by qubasta on 13.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

// Swift code for the above approach:
final class Heap<T> {
    private let compare: (T, T) -> Bool
    private var heap: [T] = []
    var count: Int { heap.count }

    init(compare: @escaping (T, T) -> Bool) {
        self.compare = compare
    }

    func enqueue(_ element: T) {
        heap.append(element)
        var currentIndex = heap.count - 1

        // Bubble up the element until the
        // heap property is restored
        while currentIndex > 0 && compare(heap[currentIndex], heap[(currentIndex-1)/2]) {
            heap.swapAt(currentIndex, (currentIndex-1)/2)
            currentIndex = (currentIndex-1)/2
        }
    }
    
    // Remove and return the top
    // element of the heap
    func dequeue() -> T? {
        guard !heap.isEmpty else {
            return nil
        }

        let topElement = heap[0]

        if heap.count == 1 {
            heap.removeFirst()
        } else {
            
            // Replace the top element
            // with the last element in
            // the heap
            heap[0] = heap.removeLast()
            var currentIndex = 0
            
            // Bubble down the element until
            // the heap property is restored
            while true {
                let leftChildIndex = 2*currentIndex+1
                let rightChildIndex = 2*currentIndex+2
                
                // Determine the index of
                // the larger child
                var maxIndex = currentIndex
                if leftChildIndex < heap.count && compare(heap[leftChildIndex], heap[maxIndex]) {
                    maxIndex = leftChildIndex
                }
                if rightChildIndex < heap.count && compare(heap[rightChildIndex], heap[maxIndex]) {
                    maxIndex = rightChildIndex
                }
                
                // If the heap property is
                // restored, break out of the loop
                if maxIndex == currentIndex {
                    break
                }
                
                // Otherwise, swap the current
                // element with its larger child
                heap.swapAt(currentIndex, maxIndex)
                currentIndex = maxIndex
            }
        }

        return topElement
    }

    func removeAll() {
        heap.removeAll()
    }

    // Get the top element of the
    // heap without removing it
    func peek() -> T? {
        return heap.first
    }

    // Check if the heap is empty
    var isEmpty: Bool {
        return heap.isEmpty
    }
}

extension Heap where T: Comparable {
    convenience init() {
        self.init(compare: { $0 < $1 })
    }
}
