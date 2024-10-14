//
//  Created by qubasta on 27.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

public struct LoadingStrategyOption: Equatable {
    let bandwidth: Int
}

public enum LoadingStrategy: Equatable {
    case automatic
    case current(LoadingStrategyOption)

    var isAutomatic: Bool {
        self == .automatic
    }
}
