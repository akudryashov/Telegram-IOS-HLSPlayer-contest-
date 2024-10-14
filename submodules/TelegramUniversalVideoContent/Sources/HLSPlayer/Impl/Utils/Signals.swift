//
//  Created by qubasta on 15.06.2024.
//

import Foundation

public class HLSSignal<T> {
    public func sink(receive block: @escaping (T) -> Void) -> Cancellable {
        fatalError("Impl me")
    }
}

final class DefaultSignal<T>: HLSSignal<T> {
    private var tokens: [Token] = []

    final class Token: Cancellable {
        var block: ((T) -> Void)?
        var cancelled: Bool = false

        init(block: @escaping (T) -> Void) {
            self.block = block
        }

        public func cancel() {
            block = nil
            cancelled = true
        }
    }

    deinit {
        tokens.forEach {
            $0.cancel()
        }
    }

    override func sink(receive block: @escaping (T) -> Void) -> any Cancellable {
        let token = Token(block: block)
        tokens.append(token)

        return token
    }

    func send(_ value: T) {
        tokens.forEach {
            $0.block?(value)
        }
    }
}

extension HLSSignal {
    func dispatch(to queue: DispatchQueue) -> HLSSignal<T> {
        DispatchQueueSignal(
            queue: queue,
            signal: self
        )
    }
}

private class DispatchQueueSignal<T>: HLSSignal<T> {
    let queue: DispatchQueue
    let signal: HLSSignal<T>

    init(
        queue: DispatchQueue,
        signal: HLSSignal<T>
    ) {
        self.queue = queue
        self.signal = signal
    }

    override func sink(receive block: @escaping (T) -> Void) -> Cancellable {
        signal.sink(receive: { [self] value in
            queue.async {
                block(value)
            }
        })
    }
}
