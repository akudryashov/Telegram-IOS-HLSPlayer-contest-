//
//  Optional+Extension.swift
//  Game
//
//  Created by qubasta on 15.06.2024.
//

import Foundation

extension Optional {
    func get(elseThrow error: Error) throws -> Wrapped {
        switch self {
        case .none:
            throw error
        case let .some(wrapped):
            return wrapped
        }
    }
    
    var isSome: Bool {
        switch self {
        case .some:
            true
        case .none:
            false
        }
    }
    
    var isNone: Bool {
        !isSome
    }
}
