//
//  BFWDatabase.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation
import SQLite3

open class Database {
    
    public let path: String
    
    // MARK: - Errors
    
    public enum Error: Swift.Error {
        case sqlite(message: String)
        case unhandledType(message: String)
    }
    
    open var sqliteError: Error {
        let message = String(cString: sqlite3_errmsg(pointer)!)
        return Error.sqlite(message: message)
    }
    
    // MARK: - Types
    
    enum ColumnType: Int {
        case integer
        case real
        case text
        case blob
        case null
        
        init(_ int32: Int32) {
            switch int32 {
            case SQLITE_INTEGER: self = .integer
            case SQLITE_FLOAT: self = .real
            case SQLITE_TEXT: self = .text
            case SQLITE_BLOB: self = .blob
            case SQLITE_NULL: self = .null
            default:
                fatalError("Unexpected SQLite type: \(int32)")
            }
        }
        
        var swiftType: Any.Type {
            switch self {
            case .integer: return Int.self
            case .real: return Float.self
            case .text: return String.self
            case .blob: return Data.self
            case .null: return NSNull.self
            }
        }
        
    }
    
    public enum ConflictAction: String {
        case ignore
        case replace
    }
    
    // From: https://stackoverflow.com/questions/28142226/sqlite-for-swift-is-unstable
    let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private var pointer: OpaquePointer?
    
    // MARK: - Init
    
    public init(path: String, open: Bool = true) throws {
        self.path = path
        if open {
            try self.open()
        }
    }
    
    deinit {
        try! close()
    }
    
    // MARK: - Functions
    
    open func guardIsOK(_ sqliteResult: Int32) throws {
        guard sqliteResult == SQLITE_OK
            else { throw sqliteError }
    }
    
    open func open() throws {
        try guardIsOK(sqlite3_open(path, &pointer))
        try execute(sql: "pragma foreign_keys = ON")
    }
    
    open func close() throws {
        try guardIsOK(sqlite3_close(pointer))
    }
    
    open func execute(sql: String) throws {
        try guardIsOK(sqlite3_exec(pointer, sql, nil, nil, nil))
    }
    
    open func executeUpdate(sql: String, arguments: [Any?] = []) throws {
        let statement = try preparedStatement(sql: sql, arguments: arguments)
        guard sqlite3_step(statement) == SQLITE_DONE
            else { throw sqliteError }
    }
    
    private func bindArgument(_ argument: Any?, toStatement statement: OpaquePointer, atIndex index: Int) throws {
        // SQLite argument index starts at 1, not 0.
        let sqliteIndex = Int32(index + 1)
        if argument == nil {
            try guardIsOK(sqlite3_bind_null(statement, sqliteIndex))
        } else if let argument = argument as? Double {
            try guardIsOK(sqlite3_bind_double(statement, sqliteIndex, argument))
        } else if let argument = argument as? String {
            try guardIsOK(sqlite3_bind_text(statement, sqliteIndex, argument, -1, SQLITE_TRANSIENT))
        } else if let argument = argument as? Int {
            try guardIsOK(sqlite3_bind_int(statement, sqliteIndex, Int32(argument)))
        } else if let argument = argument {
            throw Error.unhandledType(message: "bindArgument cannot bind a value of type \(type(of: argument))")
        }
    }
    
    private func bindArguments(_ arguments: [Any?], toStatement statement: OpaquePointer) throws {
        for (columnIndex, argument) in arguments.enumerated() {
            try bindArgument(argument, toStatement: statement, atIndex: columnIndex)
        }
    }
    
    open func preparedStatement(sql: String, arguments: [Any?] = []) throws -> OpaquePointer {
        var statement: OpaquePointer?
        try guardIsOK(sqlite3_prepare_v2(pointer, sql, -1, &statement, nil))
        try bindArguments(arguments, toStatement: statement!)
        return statement!
    }
    
    // MARK: - Introspection
    
    open func columnNamesInTable(_ tableName: String) throws -> [String] {
        let query = try Query(database: self, sql: "pragma table_info('\(tableName)')")
        var columnNames = [String]()
        while sqlite3_step(query.statement) != SQLITE_DONE {
            columnNames.append(query.value(columnIndex: 0)!)
        }
        return columnNames
    }
    
    // MARK: - insert, delete, update
    
    open func insertIntoTable(_ table: String,
                              rowDict: [String : Any],
                              conflictAction: ConflictAction? = nil) throws
    {
        let insertString = ["insert", conflictAction?.rawValue].compactMap { $0 }.joined(separator: " or ")
        let sqlDict = type(of: self).sqlDictFromRowDict(rowDict, assignListSeparator: nil)
        let sql = "\(insertString) into \"\(table)\" (\(sqlDict["columns"] as! String)) values (\(sqlDict["placeholders"] as! String))"
        try executeUpdate(sql: sql, arguments: sqlDict["arguments"] as! [Any?])
    }
    
    open func insertIntoTable(_ table: String,
                              sourceDictArray: [[String : Any]],
                              columnKeyPathMap: [String : String],
                              conflictAction: ConflictAction) throws
    {
        let columns = try columnNamesInTable(table)
        #if DEBUG
        var missingColumns = Array(columnKeyPathMap.keys)
        for tableColumn in columns {
            for mapColumn in missingColumns {
                if tableColumn.compare(mapColumn, options: .caseInsensitive) == .orderedSame {
                    missingColumns.removeAll(where: { $0 == mapColumn })
                    break
                }
            }
        }
        if !missingColumns.isEmpty {
            debugPrint("columnKeyPathMap contains columns: (\(missingColumns.joined(separator: ", "))) which aren't in the table: \(table)")
        }
        #endif
        for sourceDict in sourceDictArray {
            var mutableDict = sourceDict
            sourceDict.dictionaryWithValuesForKeyPathMap(columnKeyPathMap).forEach { (key, value) in mutableDict[key] = value }
            let rowDict = mutableDict.dictionaryWithValuesForExistingCaseInsensitiveKeys(columns)
            try insertIntoTable(table,
                                rowDict: rowDict,
                                conflictAction: conflictAction)
        }
    }
    
    open func deleteFromTable(_ table: String,
                              whereDict: [String : Any]) throws
    {
        let whereSqlDict = type(of: self).sqlDictFromRowDict(whereDict, assignListSeparator: " and ")
        let sql = "delete from \"\(table)\" where \(whereSqlDict["assign"] as! String)"
        try executeUpdate(sql: sql, arguments: whereSqlDict["arguments"] as! [Any?])
    }
    
    open func updateTable(_ table: String,
                          rowDict: [String : Any],
                          whereDict: [String : Any]) throws
    {
        let rowSqlDict = type(of: self).sqlDictFromRowDict(rowDict, assignListSeparator: ", ")
        let whereSqlDict = type(of: self).sqlDictFromRowDict(whereDict, assignListSeparator: " and ")
        let sql = "update \"\(table)\" set \(rowSqlDict["assign"] as! String) where \(whereSqlDict["assign"] as! String)"
        var arguments = rowSqlDict["arguments"] as! [Any?]
        arguments += whereSqlDict["arguments"] as! [Any?]
        try executeUpdate(sql: sql, arguments: arguments)
    }
    
    // MARK: - SQL construction
    
    public static func placeholdersStringForCount(_ count: Int) -> String {
        var placeholders = [String]()
        for _ in 0 ..< count {
            placeholders.append("?")
        }
        let placeholdersString = placeholders.joined(separator: ", ")
        return placeholdersString
    }
    
    /// Returns a dictionary with ["columns" : "columnName1", ..., "placeholders" : "?", ..., "arguments" : [value1, ...]]
    public static func sqlDictFromRowDict(_ rowDict: [String : Any],
                                          assignListSeparator: String?) -> [String : Any]
    {
        var assignArray = [String]()
        var arguments = [Any?]()
        for (columnName, value) in rowDict {
            let quotedColumnName = "\"\(columnName)\""
            let assignString = "\(quotedColumnName) = ?"
            assignArray.append(assignString)
            arguments.append(value)
        }
        let placeholdersString = placeholdersStringForCount(rowDict.count)
        let columnNames = Array(rowDict.keys)
        let quotedColumnNamesString = columnNames.joined(separator: ", ", quote: "\"")
        var sqlDict: [String : Any] = ["columns" : quotedColumnNamesString, "placeholders" : placeholdersString, "arguments" : arguments]
        if let assignListSeparator = assignListSeparator {
            let assignListString = assignArray.joined(separator: assignListSeparator)
            sqlDict["assign"] = assignListString
        }
        return sqlDict
    }
    
    public static func stringForValue(_ value: Any?,
                                      usingNullString nullString: String,
                                      quoteMark: String) -> String
    {
        let quotedQuote = "\(quoteMark)\(quoteMark)"
        let string: String
        if value is NSNull {
            string = nullString
        } else if let value = value as? String {
            let escapedQuoteString = value.replacingOccurrences(of: quoteMark, with: quotedQuote)
            string = "\(quoteMark)\(escapedQuoteString)\(quoteMark)"
        } else if value == nil {
            string = "?"
        } else {
            // TODO: Cater for Data to blob syntax
            string = String(describing: value)
        }
        return string
    }
    
}
