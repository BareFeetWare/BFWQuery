//
//  BFWCountries.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

import Foundation

class BFWCountries {

    private var databasePath: String {
        return Bundle.main.path(forResource: "Countries", ofType: "sqlite")!
    }

    lazy var database: BFWDatabase = {
		let database = BFWDatabase(path: databasePath)
		database.open()
        return database
    }()

    var queryForAllCountries: BFWQuery {
        return BFWQuery(database: database,
                        queryString: "select * from Country order by Name",
                        arguments: nil)
    }

    func queryForCountriesContaining(_ searchString: String) -> BFWQuery {
        let queryString = "select * from Country where Name like '%%' || ? || '%%' or Code like '%%' || ? || '%%'  order by Name"
        return BFWQuery(database: database,
                        queryString: queryString,
                        arguments: [searchString, searchString])
    }

}
