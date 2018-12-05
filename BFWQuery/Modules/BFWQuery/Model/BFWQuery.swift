//
//  BFWQuery.swift
//
//  Created by Tom Brodhurst-Hill on 8/09/13.
//  Copyright (c) 2013 BareFeetWare. All rights reserved.
//

import SQLite3
import FMDB

extension Array where Element == String {
    
    func joined(separator: String, quote: String) -> String {
        return map { [quote, $0, quote].joined() }.joined(separator: separator)
    }
    
}

extension Dictionary where Key == String {
    
    func objectForCaseInsensitiveKey(_ key: String) -> Any? {
        if let object = self[key] {
            return object
        } else if let caseInsensitiveKey = keys.first(where: { $0.compare(key) == .orderedSame }) {
            return self[caseInsensitiveKey]
        } else {
            return nil
        }
    }
    
    func dictionaryWithValuesForKeyPathMap(_ columnKeyPathMap: [String : String]) -> [String : Any] {
        var rowDict = [String : Any]()
        for (columnName, keyPath) in columnKeyPathMap {
            var nestedItem: Any? = self
            for key in keyPath.components(separatedBy: ".") {
                if "0123456789".contains(key) { // TODO: more robust check for number, eg if > 9
                    let index = Int(key)!
                    nestedItem = (nestedItem as! [Any])[index]
                } else {
                    nestedItem = (nestedItem as! [String : Any]).objectForCaseInsensitiveKey(key)
                }
            }
            if nestedItem != nil {
                rowDict[columnName] = nestedItem
            }
        }
        return rowDict
    }
    
    /// Similar to dictionaryWithValuesForKeys except keys are case insensitive and returns without null values
    func dictionaryWithValuesForExistingCaseInsensitiveKeys(_ keys: [String]) -> [String : Any] {
        var dictionary = [String : Any]()
        for key in keys {
            if let object = objectForCaseInsensitiveKey(key) {
                dictionary[key] = object
            }
        }
        return dictionary
    }
    
}

class BFWDatabase: FMDatabase {
    
    // MARK: - Open
    
    override func open() -> Bool {
        let success = super.open()
        if success {
            executeStatements("pragma foreign_keys = ON")
        }
        return success
    }
    
    // MARK: - Introspection
    
    func columnNamesInTable(_ tableName: String) -> [String] {
        let resultSet = try! executeQuery("pragma table_info('\(tableName)')", values: nil)
        var columnNames = [String]()
        while resultSet.next() {
            columnNames.append(resultSet.string(forColumn: "name")!)
        }
        return columnNames
    }
    
    // MARK: - insert, delete, update
    
    func insertIntoTable(_ table: String, rowDict: [String : Any]) throws {
        return try insertIntoTable(table, rowDict: rowDict, conflictAction: nil)
    }
    
    func insertIntoTable(_ table: String,
                         rowDict: [String : Any],
                         conflictAction: String?) throws // ignore or replace
    {
        let insertString = ["insert", conflictAction].compactMap { $0 }.joined(separator: " or ")
        let sqlDict = type(of: self).sqlDictFromRowDict(rowDict, assignListSeparator: nil)
        let queryString = "\(insertString) into \"\(table)\" (\(sqlDict["columns"] as! String)) values (\(sqlDict["placeholders"] as! String))"
        try executeUpdate(queryString, values: sqlDict["arguments"] as? [Any])
    }
    
    func insertIntoTable(_ table: String,
                         sourceDictArray: [[String : Any]],
                         columnKeyPathMap: [String : String],
                         conflictAction: String) throws
    {
        let columns = columnNamesInTable(table)
        #if DEBUG
        var missingColumns = Array(columnKeyPathMap.keys)
        for tableColumn in columns {
            for mapColumn in missingColumns {
                if tableColumn.compare(mapColumn) == .orderedSame {
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
    
    func deleteFromTable(_ table: String,
                         whereDict: [String : Any]) -> Bool
    {
        let whereSqlDict = type(of: self).sqlDictFromRowDict(whereDict, assignListSeparator: " and ")
        let queryString = "delete from \"\(table)\" where \(whereSqlDict["assign"] as! String)"
        let success = executeUpdate(queryString, withArgumentsIn: whereSqlDict["arguments"] as! [Any])
        return success
    }
    
    func updateTable(_ table: String,
                     rowDict: [String : Any],
                     whereDict: [String : Any]) -> Bool
    {
        let rowSqlDict = type(of: self).sqlDictFromRowDict(rowDict, assignListSeparator: ", ")
        let whereSqlDict = type(of: self).sqlDictFromRowDict(whereDict, assignListSeparator: " and ")
        let queryString = "update \"\(table)\" set \(rowSqlDict["assign"] as! String) where \(whereSqlDict["assign"] as! String)"
        var arguments = rowSqlDict["arguments"] as! [Any]
        arguments += whereSqlDict["arguments"] as! [Any]
        let success = executeUpdate(queryString, withArgumentsIn: arguments)
        return success
    }
    
    // MARK: - SQL construction
    
    static func placeholdersStringForCount(_ count: Int) -> String {
        var placeholders = [String]()
        for _ in 0 ..< count {
            placeholders.append("?")
        }
        let placeholdersString = placeholders.joined(separator: ", ")
        return placeholdersString
    }
    
    /// Returns a dictionary with ["columns" : "columnName1", ..., "placeholders" : "?", ..., "arguments" : [value1, ...]]
    static func sqlDictFromRowDict(_ rowDict: [String : Any],
                                   assignListSeparator: String?) -> [String : Any]
    {
        var assignArray = [String]()
        var arguments = [Any]()
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
    
    static func stringForValue(_ value: Any?,
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
        } else { // need to cater for NSData to blob syntax
            string = String(describing: value)
        }
        return string
    }
    
}

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

class BFWResultDictionary {
    
    // TODO: Check for retain cycle
    var resultArray: BFWResultArray
    var row: Int
    
    init(resultArray: BFWResultArray, row: Int) {
        self.resultArray = resultArray
        self.row = row
    }
    
    func object(atIndex index: Int) -> Any? {
        return resultArray.object(atRow: row, columnIndex: index)
    }
    
    func object(atIndexedSubscript index: Int) -> Any? {
        return object(atIndex: index)
    }
    
    // MARK: - NSDictionary
    
    func object(forKey key: String) -> Any? {
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
    
    var count: Int { // count the non null/nil values
        return allKeys.count
    }
    
}
