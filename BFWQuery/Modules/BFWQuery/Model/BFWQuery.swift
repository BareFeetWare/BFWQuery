//
//  BFWQuery.swift
//
//  Created by Tom Brodhurst-Hill on 8/09/13.
//  Copyright (c) 2013 BareFeetWare. All rights reserved.
//

import Foundation
import SQLite3

extension Database {
    
    open class Query {
        
        // MARK: - Variables
        
        public let database: Database
        public let sql: String
        public let arguments: [Any?]
        public let statement: OpaquePointer
        public var tableName: String? // if querying a single table or view
        
        // MARK: - Init
        
        /// Designated initializer
        public init(database: Database,
                    sql: String,
                    arguments: [Any?] = []) throws
        {
            self.database = database
            self.sql = sql
            self.arguments = arguments
            self.currentRow = -1
            self.statement = try database.preparedStatement(sql: sql, arguments: arguments)
        }
        
        public convenience init(database: Database,
                                table tableName: String,
                                columns columnNames: [String]? = nil,
                                whereDict: [String: Any]? = nil) throws
        {
            var whereString = ""
            var arguments = [Any?]()
            if let whereDict = whereDict, !whereDict.isEmpty {
                let whereSqlDict = Database.sqlDictFromRowDict(whereDict, assignListSeparator: " and ")
                whereString = " where \(whereSqlDict["assign"] as! String)"
                arguments = whereSqlDict["arguments"] as! [Any?]
            }
            var columnsString = "*"
            if let columnNames = columnNames, !columnNames.isEmpty {
                columnsString = columnNames.joined(separator: ", ", quote: "\"")
            }
            let sql = "select \(columnsString) from \"\(tableName)\"\(whereString)"
            try self.init(database: database, sql: sql, arguments: arguments)
            self.tableName = tableName
        }
        
        deinit {
            sqlite3_finalize(statement)
        }
        
        // MARK: - Computed variables
        
        public var currentRow: Int = -1 {
            didSet {
                var stepRow: Int
                if currentRow < oldValue {
                    try! database.guardIsOK(sqlite3_reset(statement))
                    stepRow = -1
                } else {
                    stepRow = oldValue
                }
                while stepRow < currentRow {
                    if sqlite3_step(statement) == SQLITE_ROW {
                        stepRow += 1
                    } else {
                        fatalError("Tried to set currentRow > number of rows in query.")
                    }
                }
            }
        }
        
        public lazy var rowCount: Int = {
            var savedCurrentRow = currentRow
            var rowCount = currentRow + 1
            while sqlite3_step(statement) == SQLITE_ROW {
                rowCount += 1
            }
            try! database.guardIsOK(sqlite3_reset(statement))
            currentRow = -1
            currentRow = savedCurrentRow
            return rowCount
        }()
        
        // MARK: - Query
        
        /// Arguments embedded in the SQL string.
        public var argumentsInSQL: String {
            let components = sql.components(separatedBy: "?")
            var descriptionArray = [String]()
            // TODO: handle if arguments is a Dictionary
            for argumentN in 0 ..< arguments.count {
                let component = components[argumentN]
                descriptionArray.append(component)
                let argument = argumentN < arguments.count
                    ? arguments[argumentN]
                    : nil
                let argumentString = Database.stringForValue(argument, usingNullString: "null", quoteMark: "'")
                descriptionArray.append(argumentString)
            }
            descriptionArray.append(components.last!)
            return descriptionArray.joined()
        }
        
        public func value<T>(atRow row: Int, columnIndex: Int) -> T? {
            currentRow = row
            return value(columnIndex: columnIndex)
        }
        
        public func value<T>(columnIndex: Int) -> T? {
            let sqliteColumn = Int32(columnIndex)
            let columnType = ColumnType(sqlite3_column_type(statement, sqliteColumn))
            switch columnType {
            case .integer: return Int(sqlite3_column_int(statement, sqliteColumn)) as? T
            case .real: return sqlite3_column_double(statement, sqliteColumn) as? T
            case .text: return String(cString: sqlite3_column_text(statement, sqliteColumn)) as? T
            case .blob: return sqlite3_column_blob(statement, sqliteColumn) as? T
            case .null: return nil
            }
        }
        
        public func value<T>(columnName: String) -> T? {
            let columnIndex = columnNames.caseInsensitiveIndex(of: columnName)!
            return value(columnIndex: columnIndex)
        }
        
        public func value<T>(atRow row: Int, columnName: String) -> T? {
            currentRow = row
            return value(columnName: columnName)
        }
        
        // MARK: - Introspection
        
        public var columnCount: Int {
            return Int(sqlite3_column_count(statement))
        }
        
        public func columnType(forIndex index: Int) -> String {
            let columnType: String
            if let columnTypeC = sqlite3_column_decltype(statement, Int32(index)) {
                columnType = String(cString: columnTypeC)
            } else {
                columnType = "" // TODO: get another way, such as sample rows or function type used in view
            }
            return columnType
        }
        
        lazy var columnDictArray: [[String : String]] = {
            var columnDictArray = [[String : String]]()
            for columnN in 0 ..< columnCount {
                let columnType = self.columnType(forIndex: columnN)
                let columnName = String(cString: sqlite3_column_name(statement, Int32(columnN)))
                var columnDict = ["name" : columnName]
                if !columnType.isEmpty {
                    columnDict["type"] = columnType
                }
                columnDictArray.append(columnDict)
            }
            return columnDictArray
        }()
        
        public var columnNames: [String] {
            return columnDictArray.map { $0["name"]! }
        }
        
        // MARK: - Caching
        
        lazy var cacheDatabase: Database = { // different database connection since different resultSet
            return try! Database(path: database.path)
        }()
        
        var cacheQuotedTableName: String {
            let unquotedSQL = sql.replacingOccurrences(of: "\"", with: "")
            let cacheQuotedTableName = "\"BFW Cache \(unquotedSQL)\""
            return cacheQuotedTableName
        }
        
        // TODO: Finish implementing caching for backwards scrolling
        
        // MARK: - NSObject
        
        public var description: String {
            return argumentsInSQL
        }
        
    }
}
