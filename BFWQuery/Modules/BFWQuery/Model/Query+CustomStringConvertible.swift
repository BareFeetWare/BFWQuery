//
//  Query+CustomStringConvertible.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 9/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation

extension Database.Query: CustomStringConvertible {
    
    // MARK: - CustomStringConvertible
    
    public var description: String {
        return argumentsInSQL
    }

    // MARK: - Functions
    
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
            let argumentString = String.sql(value: argument, usingNullString: "null", quoteMark: "'")
            descriptionArray.append(argumentString)
        }
        descriptionArray.append(components.last!)
        return descriptionArray.joined()
    }
    
}

private extension String {
    
    static func sql(value: Any?,
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
