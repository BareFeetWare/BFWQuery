//
//  BFWDatabase.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation
import FMDB

open class BFWDatabase: FMDatabase {
    
    // MARK: - Open
    
    open override func open() -> Bool {
        let success = super.open()
        if success {
            executeStatements("pragma foreign_keys = ON")
        }
        return success
    }
    
    // MARK: - Introspection
    
    open func columnNamesInTable(_ tableName: String) -> [String] {
        let resultSet = try! executeQuery("pragma table_info('\(tableName)')", values: nil)
        var columnNames = [String]()
        while resultSet.next() {
            columnNames.append(resultSet.string(forColumn: "name")!)
        }
        return columnNames
    }
    
    // MARK: - insert, delete, update
    
    open func insertIntoTable(_ table: String, rowDict: [String : Any]) throws {
        return try insertIntoTable(table, rowDict: rowDict, conflictAction: nil)
    }
    
    open func insertIntoTable(_ table: String,
                              rowDict: [String : Any],
                              conflictAction: String?) throws // ignore or replace
    {
        let insertString = ["insert", conflictAction].compactMap { $0 }.joined(separator: " or ")
        let sqlDict = type(of: self).sqlDictFromRowDict(rowDict, assignListSeparator: nil)
        let queryString = "\(insertString) into \"\(table)\" (\(sqlDict["columns"] as! String)) values (\(sqlDict["placeholders"] as! String))"
        try executeUpdate(queryString, values: sqlDict["arguments"] as? [Any])
    }
    
    open func insertIntoTable(_ table: String,
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
    
    open func deleteFromTable(_ table: String,
                              whereDict: [String : Any]) -> Bool
    {
        let whereSqlDict = type(of: self).sqlDictFromRowDict(whereDict, assignListSeparator: " and ")
        let queryString = "delete from \"\(table)\" where \(whereSqlDict["assign"] as! String)"
        let success = executeUpdate(queryString, withArgumentsIn: whereSqlDict["arguments"] as! [Any])
        return success
    }
    
    open func updateTable(_ table: String,
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
        } else { // need to cater for NSData to blob syntax
            string = String(describing: value)
        }
        return string
    }
    
}
