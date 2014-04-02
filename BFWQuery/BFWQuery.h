//
//  BFWQuery.h
//
//  Created by Tom Brodhurst-Hill on 8/09/13.
//  Copyright (c) 2013 BareFeetWare. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"

@class FMResultSet;
@class BFWQuery;

@interface NSDictionary (BFWQuery)

- (id)objectForCaseInsensitiveKey:(id)key;
- (NSDictionary*)dictionaryWithValuesForKeyPathMap:(NSDictionary*)columnKeyPathMap;
- (NSDictionary*)dictionaryByRemovingNulls;
- (NSDictionary*)dictionaryWithValuesForExistingCaseInsensitiveKeys:(NSArray*)keys;

@end

@interface BFWDatabase : FMDatabase

#pragma mark - transactions

- (BOOL)beginImmediateTransaction;

#pragma mark - introspection

- (NSArray*)columnNamesInTable:(NSString*)tableName;

#pragma mark - insert, delete, update

- (BOOL)insertIntoTable:(NSString*)table
				rowDict:(NSDictionary*)rowDict;

- (BOOL)insertIntoTable:(NSString*)table
                rowDict:(NSDictionary*)rowDict
         conflictAction:(NSString*)conflictAction; // nil or @"ignore" or @"replace"

- (BOOL)insertIntoTable:(NSString*)table
        sourceDictArray:(NSArray*)sourceDictArray
       columnKeyPathMap:(NSDictionary*)columnKeyPathMap
         conflictAction:(NSString*)conflictAction; // nil or @"ignore" or @"replace"

- (BOOL)deleteFromTable:(NSString*)table
              whereDict:(NSDictionary*)whereDict;

- (BOOL)updateTable:(NSString*)table
            rowDict:(NSDictionary*)rowDict
		  whereDict:(NSDictionary*)whereDict;

#pragma mark - SQL construction

+ (NSDictionary*)sqlDictFromRowDict:(NSDictionary*)rowDict
				assignListSeparator:(NSString*)assignListSeparator;

@end

@class BFWResultArray;

@interface BFWQuery : NSObject

@property (nonatomic, strong) BFWDatabase* database;
@property (nonatomic, strong) NSString* queryString;
@property (nonatomic, strong) NSArray* arguments;

@property (nonatomic, assign) NSInteger currentRow;
@property (nonatomic, strong) BFWResultArray* resultArray;

@property (nonatomic, strong, readonly) FMResultSet* resultSet;
@property (nonatomic, assign, readonly) NSInteger rowCount;
@property (nonatomic, strong, readonly) NSArray* columns;

@property (nonatomic, strong) NSString* tableName; // if querying a single table or view

#pragma mark - init

 // designated initializer:
- (instancetype)initWithDatabase:(BFWDatabase*)database
                     queryString:(NSString*)queryString
                       arguments:(NSArray*)arguments;

- (instancetype)initWithDatabase:(BFWDatabase*)database
                           table:(NSString*)tableName;

- (instancetype)initWithDatabase:(BFWDatabase*)database
                           table:(NSString*)tableName
                         columns:(NSArray*)columnNames
                       whereDict:(NSDictionary*)whereDict;

#pragma mark - other

- (void)reload;
- (void)resetStatement;

@end

@interface BFWResultArray : NSArray

- (instancetype)initWithQuery:(BFWQuery*)query;

@end


