//
//  PreparedStatement.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 11/2/20.
//  Copyright © 2020 BareFeetWare. All rights reserved.
//

import Foundation
import SQLite3

extension Database {
    class PreparedStatement {
        
        let database: Database
        
        var statementPointer: OpaquePointer?
        
        init(database: Database, sql: String, arguments: [Any?] = []) throws {
            self.database = database
            try database.guardIsOK(sqlite3_prepare_v2(database.pointer, sql, -1, &statementPointer, nil))
            try bindArguments(arguments)
        }
        
        deinit {
            sqlite3_finalize(statementPointer)
        }
        
    }
}

extension Database.PreparedStatement {
    
    func step() -> Int32 {
        sqlite3_step(statementPointer)
    }
    
    func reset() -> Int32 {
        sqlite3_reset(statementPointer)
    }
    
    private func bindArgument(_ argument: Any?, atIndex index: Int) throws {
        // SQLite argument index starts at 1, not 0.
        let sqliteIndex = Int32(index + 1)
        if argument == nil {
            try guardIsOK(sqlite3_bind_null(statementPointer, sqliteIndex))
        } else if let argument = argument as? Double {
            try guardIsOK(sqlite3_bind_double(statementPointer, sqliteIndex, argument))
        } else if let argument = argument as? String {
            try guardIsOK(sqlite3_bind_text(statementPointer, sqliteIndex, argument, -1, database.SQLITE_TRANSIENT))
        } else if let argument = argument as? Int {
            try guardIsOK(sqlite3_bind_int(statementPointer, sqliteIndex, Int32(argument)))
        } else if let argument = argument {
            throw Database.Error.unhandledType(message: "bindArgument cannot bind a value of type \(type(of: argument))")
        }
    }
    
    internal func bindArguments(_ arguments: [Any?]) throws {
        for (columnIndex, argument) in arguments.enumerated() {
            try bindArgument(argument, atIndex: columnIndex)
        }
    }
    
    func guardIsOK(_ sqliteResult: Int32) throws {
        try database.guardIsOK(sqliteResult)
    }
    
}
