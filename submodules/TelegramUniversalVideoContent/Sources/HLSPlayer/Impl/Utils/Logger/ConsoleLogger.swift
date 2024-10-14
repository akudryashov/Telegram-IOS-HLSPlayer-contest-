//
//  Created by qubasta on 23.06.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

final class ConsoleLogger: Logger {
    func logMessage(
        _ message: @autoclosure () -> (String),
        with logLevel: LogLevel
    ) {
        print(logLevel.emoji + message())
    }
}

extension LogLevel {
    fileprivate var emoji: String {
        switch self {
        case .debug:
            "🔨 DEBUG: "
        case .info:
            "🔍 INFO: "
        case .warn:
            "⚠️ WARN: "
        case .error:
            "🛑 ERROR: "
        }
    }
}
