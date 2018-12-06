//
//  BFWQueryTests.m
//  BFWQueryTests
//
//  Created by Tom Brodhurst-Hill on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

import FMDB
import XCTest
@testable import BFWQuery

class BFWQueryTests: XCTestCase {
    
    // MARK: - Variables
    
    let databasePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TestDatabase.sqlite").path
    var database: BFWDatabase!
    
    // MARK: - Setup and tear down
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        createDatabase()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        deleteDatabase()
    }
    
    func createDatabase() {
        database = BFWDatabase(path: databasePath)
        var success = database.open()
        if success {
            success = database.beginImmediateTransaction()
            if success {
                let createTableSql = """
create table Test
(    id integer primary key not null
,    name text not null
,    row integer
)
"""
                success = database.executeUpdate(createTableSql, withArgumentsIn: [])
                if success {
                    // Created successfully
                } else {
                    XCTFail("Failed test \"\(#function)\", SQL error: \(database.lastErrorMessage)")
                }
            } else {
                XCTFail("Failed test \"\(#function)\", SQL error: \(database.lastErrorMessage)")
            }
        } else {
            XCTFail("Failed test \"\(#function)\", SQL error: \(database.lastErrorMessage)")
        }
    }
    
    func deleteDatabase() {
        database.close()
        try! FileManager.default.removeItem(atPath: databasePath)
    }
    
    func emptyTable() {
        database.executeUpdate("delete * from Test", withArgumentsIn: [])
    }
    
    // MARK: - Tests
    
    func testCaseInsensitiveKeysInQuery() {
        try! database.insertIntoTable("Test", rowDict: ["name" : "Tom"])
        let query = BFWQuery(database: database, queryString: "select * from Test", arguments: nil)
        let countryDict = query.resultArray.dictionary(atRow: 0)
        let isCaseInsensitiveKeys = (countryDict.object(forKey: "name") as! String) == (countryDict.object(forKey: "Name") as! String)
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
            let query = BFWQuery(database: database,
                                 table: "Test",
                                 columns: ["id", "name", "row"],
                                 whereDict: ["name" : "tom"])
            debugPrint("BFWQuery rowCount start")
            let rowCount = query.rowCount
            debugPrint("BFWQuery rowCount end. rowCount = \(rowCount)")
            let countQuery = BFWQuery(database: database,
                                      queryString: "select count(*) as count from Test where name = ?",
                                      arguments: ["Tom"])
            debugPrint("count(*) start")
            let starCount = countQuery.resultArray.object(atRow: 0, columnName: "count")!
            debugPrint("count(*) end. Count = \(starCount)")
        }
        if !success {
            XCTFail("Failed test \"\(#function)\", SQL error: \(database.lastErrorMessage)")
        }
    }
    
}
