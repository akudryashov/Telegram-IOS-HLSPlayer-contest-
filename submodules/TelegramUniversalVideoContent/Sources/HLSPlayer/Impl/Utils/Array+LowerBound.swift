//
//  Created by qubasta on 13.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import Foundation

extension Array {
    func lowerBound(
        searchItem: Element,
        compare: (Element, Element) -> Bool
    ) -> Element? {
        guard !isEmpty else {
            return nil
        }
        var lowerIndex = 0
        var upperIndex = count - 1
        var answer = last

        while lowerIndex <= upperIndex {
            let currentIndex = (lowerIndex + upperIndex) / 2
            let currentItem = self[currentIndex]

            if compare(currentItem, searchItem) {
                lowerIndex = currentIndex + 1
            } else {
                answer = currentItem
                upperIndex = currentIndex - 1
            }
        }

        return answer
    }
}

extension Array where Element: Comparable {
    func lowerBound(searchItem: Element) -> Element? {
        lowerBound(searchItem: searchItem, compare: <)
    }
}
