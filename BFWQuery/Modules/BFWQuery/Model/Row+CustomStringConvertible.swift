//
//  Row+CustomStringConvertible.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 10/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation

extension Database.Query.Row: CustomStringConvertible {
    
    public var description: String {
        return String(describing: dictionary)
    }
    
}
