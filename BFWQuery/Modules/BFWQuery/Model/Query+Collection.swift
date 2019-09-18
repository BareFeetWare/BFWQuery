//
//  Query+Collection.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 19/9/19.
//  Copyright © 2019 BareFeetWare. All rights reserved.
//

import Foundation

extension Database.Query: Collection {
    
    public func index(after i: Int) -> Int {
        i + 1
    }
    
    public var startIndex: Int {
        0
    }
    
    public var endIndex: Int {
        rowCount
    }
    
}
