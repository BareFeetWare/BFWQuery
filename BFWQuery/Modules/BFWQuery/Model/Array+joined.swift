//
//  Array+joined.swift
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation

extension Array where Element == String {
    
    func joined(separator: String, quote: String) -> String {
        return map { [quote, $0, quote].joined() }.joined(separator: separator)
    }
    
}
