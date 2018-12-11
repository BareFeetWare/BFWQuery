//
//  Array+case.swift
//
//  Created by Tom Brodhurst-Hill on 9/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation

extension Array where Element == String {
    
    func caseInsensitiveIndex(of element: String) -> Int? {
        return index(of: element)
            ?? firstIndex { $0.compare(element, options: .caseInsensitive) == .orderedSame }
    }
    
}
