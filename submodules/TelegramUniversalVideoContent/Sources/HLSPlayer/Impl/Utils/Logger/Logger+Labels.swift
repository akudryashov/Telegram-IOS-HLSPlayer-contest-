//
//  Created by qubasta on 23.06.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

extension Logger {
    func labels(_ tag: String) -> Logger {
        LoggerTag(subject: self, tag: tag)
    }
}

private struct LoggerTag: Logger {
    let subject: Logger
    let tag: String
    
    func logMessage(_ message: @autoclosure () -> (String), with logLevel: LogLevel) {
        subject.logMessage(
            "[\(tag)] " + message(),
            with: logLevel
        )
    }
}
