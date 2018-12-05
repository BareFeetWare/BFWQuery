//
//  BFWResultArray.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation
import FMDB

class BFWResultArray {
    
    weak var query: BFWQuery!
    
    init(query: BFWQuery) {
        self.query = query
    }
    
    var columnCount: Int {
        return query.columnCount
    }
    
    func dictionary(atRow row: Int) -> BFWResultDictionary {
        return BFWResultDictionary(resultArray: self, row:row)
    }
    
    func object(atRow row: Int,
                columnIndex: Int) -> Any?
    {
        query.currentRow = row
        return query.resultSet.object(forColumnIndex: Int32(columnIndex))
    }
    
    func object(atRow row: Int,
                columnName: String) -> Any?
    {
        query.currentRow = row
        var object = query.resultSet.object(forColumn: columnName)
        if object is NSNull {
            object = nil
        }
        return object
    }
    
    // MARK: - NSArray
    
    func object(atIndex index: Int) -> Any {
        return dictionary(atRow: index)
    }
    
    var count: Int {
        return query!.rowCount
    }
    
}
