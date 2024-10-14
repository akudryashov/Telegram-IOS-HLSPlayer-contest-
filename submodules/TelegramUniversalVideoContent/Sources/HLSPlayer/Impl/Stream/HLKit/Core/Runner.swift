import Foundation

/// A type that methods for running.
public protocol Runner: AnyObject {
    var isRunning: Bool { get }
    /// Tells the receiver to start running.
    func start()
    /// Tells the receiver to stop running.
    func pause(reset: Bool)
}
