//
//  BFWCountries.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

import Foundation
import BFWQuery

class BFWCountries {
    
    private var databasePath: String {
        return Bundle.main.path(forResource: "Countries", ofType: "sqlite")!
    }
    
    lazy var database: Database = {
        return try! Database(path: databasePath)
    }()
    
    var queryForAllCountries: Database.Query {
        return try! database.query(table: "Country")
    }
    
    func queryForCountriesContaining(_ searchString: String) -> Database.Query {
        let sql = """
select * from Country
where name like '%%' || ? || '%%' or code like '%%' || ? || '%%'
order by name
"""
        return try! database.query(sql: sql,
                                   arguments: [searchString, searchString])
    }
    
}
