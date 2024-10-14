//
//  Logger.swift
//  Game
//
//  Created by qubasta on 15.06.2024.
//

import Foundation

enum LogLevel: String {
    case debug
    case info
    case warn
    case error
}

protocol Logger {
    func logMessage(
        _ message: @autoclosure () -> (String),
        with logLevel: LogLevel
    )
}

extension Logger {
    func debug(
        _ message: @autoclosure () -> (String)
    ) {
        logMessage(message(), with: .debug)
    }

    func info(
        _ message: @autoclosure () -> (String)
    ) {
        logMessage(message(), with: .info)
    }
    
    func warn(
        _ message: @autoclosure () -> (String)
    ) {
        logMessage(message(), with: .warn)
    }
    
    func error(
        _ message: @autoclosure () -> (String)
    ) {
        logMessage(message(), with: .error)
    }
}
