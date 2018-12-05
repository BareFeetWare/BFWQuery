//
//  BFWQuery.swift
//
//  Created by Tom Brodhurst-Hill on 8/09/13.
//  Copyright (c) 2013 BareFeetWare. All rights reserved.
//

import Foundation
import FMDB

class BFWQuery {
    
    var database: BFWDatabase
    var queryString: String
    var arguments: Any?
    
    var tableName: String? // if querying a single table or view
    
    // MARK: - Init
    
    /// Designated initializer
    init(database: BFWDatabase,
         queryString: String,
         arguments: Any?)
    {
        self.database = database
        self.queryString = queryString
        self.arguments = arguments
        self.currentRow = -1
    }
    
    convenience init(database: BFWDatabase,
                     table tableName: String)
    {
        self.init(database:database, table: tableName, columns: nil, whereDict: nil)
    }
    
    convenience init(database: BFWDatabase,
                     table tableName: String,
                     columns columnNames: [String]?,
                     whereDict: [String: Any]?)
    {
        var whereString = ""
        var arguments: [Any]?
        if let whereDict = whereDict, !whereDict.isEmpty {
            let whereSqlDict = BFWDatabase.sqlDictFromRowDict(whereDict, assignListSeparator: " and ")
            whereString = " where \(whereSqlDict["assign"] as! String)"
            arguments = whereSqlDict["arguments"] as! [Any]?
        }
        var columnsString = "*"
        if let columnNames = columnNames, !columnNames.isEmpty {
            columnsString = columnNames.joined(separator: ", ", quote: "\"")
        }
        let queryString = "select \(columnsString) from \"\(tableName)\"\(whereString)"
        self.init(database: database, queryString: queryString, arguments: arguments)
        self.tableName = tableName
    }
    
    // MARK: - Query
    
    var sqlString: String {
        let components = queryString.components(separatedBy: "?")
        var descriptionArray = [String]()
        let arguments = self.arguments as! [Any]
        // TODO: handle if arguments is a Dictionary
        for argumentN in 0 ..< arguments.count {
            let component = components[argumentN]
            descriptionArray.append(component)
            let argument = argumentN < arguments.count
                ? arguments[argumentN]
                : nil
            let argumentString = BFWDatabase.stringForValue(argument, usingNullString: "null", quoteMark: "'")
            descriptionArray.append(argumentString)
        }
        descriptionArray.append(components.last!)
        let sqlString = descriptionArray.joined()
        return sqlString
    }
    
    // MARK: - Result set
    
    private var _resultSet: FMResultSet?
    
    var resultSet: FMResultSet {
        if _resultSet == nil {
            if let arguments = arguments as? [String : Any] {
                _resultSet = database.executeQuery(queryString,
                                                   withParameterDictionary: arguments)
            } else {
                let arguments = self.arguments as? [Any] ?? []
                _resultSet = database.executeQuery(queryString,
                                                   withArgumentsIn: arguments)
            }
            if _resultSet == nil {
                debugPrint("resultSet error = \(database.lastError())")
            }
        }
        return _resultSet!
    }
    
    private var _currentRow = -1
    
    var currentRow: Int {
        get {
            return _currentRow
        }
        set {
            if newValue < _currentRow {
                resetStatement()
            }
            while _currentRow < newValue && resultSet.next() {
                _currentRow += 1
                //debugPrint("_currentRow + 1 = \(_currentRow)")
            }
        }
    }
    
    private var _rowCount = -1
    
    var rowCount: Int {
        if _rowCount == -1 {
            while resultSet.next() {
                _currentRow += 1
            }
            _rowCount = _currentRow + 1
            resetStatement()
        }
        return _rowCount
    }
    
    func resetStatement() {
        resultSet.statement?.reset()
        //TODO: why doesn't above work?
        _resultSet = nil
        _currentRow = -1
    }
    
    func reload() {
        _rowCount = -1
        resetStatement()
    }
    
    func object(atRow row: Int, columnIndex: Int) -> Any? {
        currentRow = row
        var object = resultSet.object(forColumnIndex: Int32(columnIndex))
        if object is NSNull {
            // TODO: re-implement FMResultSet's objectForColumnIndex to prevent swap of nil/NSNull
            object = nil
        }
        return object
    }
    
    lazy var resultArray: BFWResultArray = {
        return BFWResultArray(query: self)
    }()
    
    // MARK: - Introspection
    
    var columnCount: Int {
        return Int(resultSet.columnCount)
    }
    
    lazy var columnDictArray: [[String : String]] = {
        var columnDictArray = [[String : String]]()
        for columnN in 0 ..< resultSet.columnCount {
            let columnType = resultSet.columnType(forIndex: Int(columnN))
            var columnDict = ["name" : resultSet.columnName(for: columnN)!]
            if !columnType.isEmpty {
                columnDict["type"] = columnType
            }
            columnDictArray.append(columnDict)
        }
        return columnDictArray
    }()
    
    var columnNames: [String] {
        return columnDictArray.map { $0["name"]! }
    }
    
    // MARK: - Caching
    
    lazy var cacheDatabase: BFWDatabase = { // different database connection since different resultSet
        let cacheDatabase = BFWDatabase(path: database.databasePath)
        _ = cacheDatabase.open()
        return cacheDatabase
    }()
    
    var cacheQuotedTableName: String {
        let unquotedQueryString = queryString.replacingOccurrences(of: "\"", with: "")
        let cacheQuotedTableName = "\"BFW Cache \(unquotedQueryString)\""
        return cacheQuotedTableName
    }
    
    // TODO: Finish implementing caching for backwards scrolling
    
    // MARK: - NSObject
    
    var description: String {
        return sqlString
    }
    
}
