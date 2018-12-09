//
//  BFWResultArray.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation

open class BFWResultArray {
    
    open var query: Database.Query!
    
    init(query: Database.Query) {
        self.query = query
    }
    
    open var columnCount: Int {
        return query.columnCount
    }
    
    open func dictionary(atRow row: Int) -> BFWResultDictionary {
        return BFWResultDictionary(resultArray: self, row:row)
    }
    
    open func value<T>(atRow row: Int,
                       columnIndex: Int) -> T?
    {
        query.currentRow = row
        return query.value(columnIndex: columnIndex)
    }
    
    open func value<T>(atRow row: Int,
                       columnName: String) -> T?
    {
        query.currentRow = row
        return query.value(columnName: columnName)
    }
    
    // MARK: - NSArray
    
    open func rowDict(atIndex index: Int) -> BFWResultDictionary {
        return dictionary(atRow: index)
    }
    
    open var count: Int {
        return query!.rowCount
    }
    
}
