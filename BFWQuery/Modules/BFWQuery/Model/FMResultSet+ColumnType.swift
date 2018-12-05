//
//  FMResultSet+ColumnType.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation
import FMDB
import SQLite3

extension FMResultSet {
    
    func columnType(forIndex index: Int) -> String {
        let columnType: String
        let opaqueStatement = OpaquePointer(statement!.statement)
        if let columnTypeC = sqlite3_column_decltype(opaqueStatement, Int32(index)) {
            columnType = String(cString: columnTypeC)
        } else {
            columnType = "" // TODO: get another way, such as sample rows or function type used in view
        }
        return columnType
    }
    
}
