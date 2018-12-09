//
//  BFWQueryTests.swift
//  BFWQueryTests
//
//  Created by Tom Brodhurst-Hill on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

import XCTest
@testable import BFWQuery

class BFWQueryTests: XCTestCase {
    
    // MARK: - Variables
    
    let databasePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TestDatabase.sqlite").path
    var database: Database!
    
    // MARK: - Setup and tear down
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try! createDatabase()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try! deleteDatabase()
    }
    
    func createDatabase() throws {
        try? FileManager.default.removeItem(atPath: databasePath)
        database = try Database(path: databasePath)
        let createTableSql = """
create table Test
(    id integer primary key not null
,    name text not null
,    row integer
)
"""
        try database.executeUpdate(sql: createTableSql)
    }
    
    func deleteDatabase() throws {
        try? database.close()
        try FileManager.default.removeItem(atPath: databasePath)
    }
    
    func emptyTable() throws {
        try database.executeUpdate(sql: "delete * from Test")
    }
    
    // MARK: - Tests
    
    func testCaseInsensitiveKeysInQuery() {
        try! database.insertIntoTable("Test", rowDict: ["name" : "Tom"])
        let query = try! Database.Query(database: database, table: "Test")
        query.currentRow = 0
        let lowerKeyValue: String = query.value(columnName: "name")!
        let upperKeyValue: String = query.value(columnName: "Name")!
        let isCaseInsensitiveKeys = lowerKeyValue == upperKeyValue
        if !isCaseInsensitiveKeys {
            XCTFail("Failed test \"\(#function)\"")
        }
    }
    
    func testInsertAndCount() {
        var success = true
        for rowN in 0 ..< 100 {
            if success {
                do {
                    try database.insertIntoTable("Test",
                                                 rowDict: ["name" : "Tom",
                                                           "row" : rowN + 1])
                } catch {
                    success = false
                }
            } else {
                break
            }
        }
        if success {
            let query = try! Database.Query(database: database,
                                            table: "Test",
                                            columns: ["id", "name", "row"],
                                            whereDict: ["name" : "tom"])
            debugPrint("BFWQuery rowCount start")
            let rowCount = query.rowCount
            debugPrint("BFWQuery rowCount end. rowCount = \(rowCount)")
            let countQuery = try! Database.Query(database: database,
                                                 sql: "select count(*) as count from Test where name = ?",
                                                 arguments: ["Tom"])
            debugPrint("count(*) start")
            countQuery.currentRow = 0
            let starCount: Int = countQuery.value(columnName: "count")!
            debugPrint("count(*) end. Count = \(starCount)")
        }
        if !success {
            XCTFail("Failed test \"\(#function)\", SQL error: \(database.sqliteError)")
        }
    }
    
}
