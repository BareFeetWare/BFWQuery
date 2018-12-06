//
//  BFWResultDictionary.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation
import FMDB

open class BFWResultDictionary {
    
    // TODO: Check for retain cycle
    open var resultArray: BFWResultArray
    open var row: Int
    
    init(resultArray: BFWResultArray, row: Int) {
        self.resultArray = resultArray
        self.row = row
    }
    
    open func object(atIndex index: Int) -> Any? {
        return resultArray.object(atRow: row, columnIndex: index)
    }
    
    open func object(atIndexedSubscript index: Int) -> Any? {
        return object(atIndex: index)
    }
    
    // MARK: - NSDictionary
    
    open func object(forKey key: String) -> Any? {
        return resultArray.object(atRow: row, columnName: key)
    }
    
    lazy var allKeys: [String] = {
        var allKeys = [String]()
        let columnNames = resultArray.query.columnNames
        for columnIndex in 0 ..< columnNames.count {
            if let object = resultArray.object(atRow: row, columnIndex: columnIndex),
                !(object is NSNull)
            {
                // TODO: bypass FMDB's objectForColumnIndex so no NSNulls
                allKeys.append(columnNames[columnIndex])
            }
        }
        return allKeys
    }()
    
    open var count: Int { // count the non null/nil values
        return allKeys.count
    }
    
}
