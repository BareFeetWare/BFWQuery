//
//  Row.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

// This file must be listed in Build Phases -> Compile Sources, after Query, to satisfy the compiler. Probably a Swift compiler bug:
// https://bugs.swift.org/browse/SR-631

import Foundation

public extension Database.Query {
    
    func row(number: Int) -> Database.Query.Row {
        return Database.Query.Row(query: self, row: number)
    }
    
    subscript(index: Int) -> Row {
        return row(number: index)
    }
    
    struct Row {
        
        // MARK: - Variables
        
        public let query: Database.Query
        public let row: Int
        
        // MARK: - Functions and computed variables
        
        public func value<T>(columnIndex: Int) -> T? {
            return query.value(atRow: row, columnIndex: columnIndex)
        }
        
        public func value<T>(columnName: String) -> T? {
            return query.value(atRow: row, columnName: columnName)
        }
        
        public subscript<T>(columnIndex: Int) -> T? {
            return value(columnIndex: columnIndex)
        }
        
        public subscript<T>(columnName: String) -> T? {
            return value(columnName: columnName)
        }
        
        public var values: [Any?] {
            var values = [Any?]()
            for columnN in 0 ..< query.columnCount {
                values.append(value(columnIndex: columnN))
            }
            return values
        }
        
        public var dictionary: [String : Any?] {
            return Dictionary(uniqueKeysWithValues: zip(query.columnNames, values))
        }
        
    }
}
