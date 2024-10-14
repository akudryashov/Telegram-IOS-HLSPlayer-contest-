import Foundation

/// Atomic<T> class
/// - seealso: https://www.objc.io/blog/2018/12/18/atomic-variables/
@propertyWrapper
struct Atomic<A> {
    private let queue = DispatchQueue(
        label: "com.hlsplayer.atomic",
        attributes: .concurrent
    )
    private var _value: A

    /// Getter for the value.
    var value: A { queue.sync { self._value } }
    var wrappedValue: A {
        get {
            value
        }
        set {
            mutate { $0 = newValue }
        }
    }

    /// Creates an instance of value.
    init(_ value: A) {
        self._value = value
    }

    /// Setter for the value.
    mutating func mutate<R>(_ transform: (inout A) -> R) -> R {
        queue.sync(flags: .barrier) {
            transform(&self._value)
        }
    }
}
