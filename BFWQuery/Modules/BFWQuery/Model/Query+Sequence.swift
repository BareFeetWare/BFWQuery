//
//  Query+Sequence.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation

extension Database.Query: Sequence, IteratorProtocol {

    public func next() -> Row? {
        return currentRow < rowCount
            ? row(number: currentRow)
            : nil
    }

}
