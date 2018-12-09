//
//  BFWResultDictionary.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation

open class BFWResultDictionary {
    
    // TODO: Check for retain cycle
    open var resultArray: BFWResultArray
    open var row: Int
    
    init(resultArray: BFWResultArray, row: Int) {
        self.resultArray = resultArray
        self.row = row
    }
    
    open func value<T>(atIndex index: Int) -> T? {
        return resultArray.value(atRow: row, columnIndex: index)
    }
    
    // MARK: - NSDictionary
    
    open func value<T>(forKey key: String) -> T? {
        return resultArray.query.value(atRow: row, columnName: key)
    }
    
    lazy var allKeys: [String] = {
        return resultArray.query.columnNames
    }()
    
    open var count: Int { // count the non null/nil values
        return allKeys.count
    }
    
}
