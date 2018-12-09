//
//  Dictionary+case.swift
//
//  Created by Tom Brodhurst-Hill on 6/12/18.
//  Copyright © 2018 BareFeetWare. All rights reserved.
//

import Foundation

extension Dictionary where Key == String {
    
    func objectForCaseInsensitiveKey(_ key: String) -> Any? {
        if let object = self[key] {
            return object
        } else if let caseInsensitiveKey = keys.first(where: { $0.compare(key, options: .caseInsensitive) == .orderedSame }) {
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
