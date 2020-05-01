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
    
    internal var pointer: OpaquePointer?
    
    // MARK: - Init
    
    public init(path: String, open: Bool = true) throws {
        self.path = path
        if open {
            try self.open()
        }
    }
    
    deinit {
        do {
            try close()
        } catch {
            print("\(#function) failed to close database \(path)")
        }
    }
    
    // MARK: - Errors
    
    public enum Error: Swift.Error, LocalizedError {
        case sqlite(message: String)
        case unhandledType(message: String)
        
        public var errorDescription: String? {
            switch self {
            case .sqlite(let message): return "SQLite: \(message)"
            case .unhandledType(let message): return "Database: \(message)"
            }
        }
        
    }
    
    open var sqliteError: Error {
        let message = String(cString: sqlite3_errmsg(pointer)!)
        return Error.sqlite(message: message)
    }
    
    open func guardIsOK(_ sqliteResult: Int32) throws {
        guard sqliteResult == SQLITE_OK
            else { throw sqliteError }
    }
    
    // From: https://stackoverflow.com/questions/28142226/sqlite-for-swift-is-unstable
    let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
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
    
    // MARK: - Functions
    
    open func open() throws {
        try guardIsOK(sqlite3_open(path, &pointer))
        try execute(sql: "pragma foreign_keys = ON")
    }
    
    open func close() throws {
        try guardIsOK(sqlite3_close(pointer))
    }
    
    /// Execute multi line SQL, separated by ";".
    open func execute(sql: String) throws {
        try guardIsOK(sqlite3_exec(pointer, sql, nil, nil, nil))
    }
    
    /// Execute single line SQL, up to first ";".
    open func executeUpdate(sql: String, arguments: [Any?] = []) throws {
        let statement = try PreparedStatement(database: self, sql: sql, arguments: arguments)
        guard sqlite3_step(statement.statementPointer) == SQLITE_DONE
            else { throw sqliteError }
    }
    
    // MARK: - Introspection
    
    open func columnNamesInTable(_ tableName: String) throws -> [String] {
        let query = try self.query(sql: "pragma table_info('\(tableName)')")
        var columnNames = [String]()
        while sqlite3_step(query.statement.statementPointer) != SQLITE_DONE {
            columnNames.append(query.value(columnIndex: 0)!)
        }
        return columnNames
    }
    
    // MARK: - insert, delete, update
    
    open func insertIntoTable(_ table: String,
                              rowDict: [String : Any?],
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
    
    open func deleteAllFromTable(_ table: String) throws {
        let sql = "delete from \"\(table)\""
        try executeUpdate(sql: sql)
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
    
    // MARK: - Transactions
    
    open func beginImmediate() throws {
        try execute(sql: "begin immediate")
    }
    
    open func rollback() throws {
        try execute(sql: "rollback")
    }
    
    open func commit() throws {
        try execute(sql: "commit")
    }
    
    open func executeInTransaction(actions: () throws -> Void) throws {
        try beginImmediate()
        do {
            try actions()
            try commit()
        } catch {
            debugPrint("rollback due to error: \(error)")
            try rollback()
            throw error
        }
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
    public static func sqlDictFromRowDict(_ rowDict: [String : Any?],
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
    
}
