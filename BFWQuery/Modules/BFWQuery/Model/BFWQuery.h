//
//  BFWQuery.h
//
//  Created by Tom Brodhurst-Hill on 8/09/13.
//  Copyright (c) 2013 BareFeetWare. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <fmdb/FMDB.h>

@class FMResultSet;
@class BFWQuery;

@interface NSDictionary (BFWQuery)

- (id)objectForCaseInsensitiveKey:(id)key;
- (NSDictionary*)dictionaryWithValuesForKeyPathMap:(NSDictionary*)columnKeyPathMap;
- (NSDictionary*)dictionaryWithValuesForExistingCaseInsensitiveKeys:(NSArray*)keys;

@end

@interface BFWDatabase : FMDatabase

#pragma mark introspection

- (NSArray*)columnNamesInTable:(NSString*)tableName;

#pragma mark insert, delete, update

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

#pragma mark SQL construction

+ (NSDictionary*)sqlDictFromRowDict:(NSDictionary*)rowDict
				assignListSeparator:(NSString*)assignListSeparator;

@end

@class BFWResultArray;

@interface BFWQuery : NSObject

@property (nonatomic, strong) BFWDatabase* database;
@property (nonatomic, strong) NSString* queryString;
@property (nonatomic, strong) id arguments;

@property (nonatomic, readonly) NSString* sqlString;

@property (nonatomic, assign) NSInteger currentRow;
@property (nonatomic, strong) BFWResultArray* resultArray;

@property (nonatomic, strong, readonly) FMResultSet* resultSet;
@property (nonatomic, assign, readonly) NSInteger rowCount;
@property (nonatomic, strong, readonly) NSArray* columnDictArray;

@property (nonatomic, strong) NSString* tableName; // if querying a single table or view

#pragma mark init

 // designated initializer:
- (instancetype)initWithDatabase:(BFWDatabase*)database
                     queryString:(NSString*)queryString
                       arguments:(id)arguments;

- (instancetype)initWithDatabase:(BFWDatabase*)database
                           table:(NSString*)tableName;

- (instancetype)initWithDatabase:(BFWDatabase*)database
                           table:(NSString*)tableName
                         columns:(NSArray*)columnNames
                       whereDict:(NSDictionary*)whereDict;

#pragma mark derived accessors

- (NSString*)description;
- (NSUInteger)columnCount;
- (NSArray*)columnNames;

#pragma mark reload & reset

- (void)reload;
- (void)resetStatement;

@end

@class BFWResultDictionary;

@interface BFWResultArray : NSArray

@property (nonatomic, weak) BFWQuery* query;

- (instancetype)initWithQuery:(BFWQuery*)query;
- (BFWResultDictionary*)dictionaryAtRow:(NSUInteger)row;
- (id)objectAtRow:(NSUInteger)row columnIndex:(NSUInteger)columnIndex;
- (id)objectAtRow:(NSUInteger)row columnName:(NSString*)columnName;

@end

@interface BFWResultDictionary : NSDictionary

@property (nonatomic, strong) BFWResultArray* resultArray; //TODO: check for retain cycle
@property (nonatomic) NSInteger row;

- (instancetype)initWithResultArray:(BFWResultArray*)resultArray
								row:(NSUInteger)row;

#pragma mark NSArray like access

- (id)objectAtIndex:(NSUInteger)index;
- (id)objectAtIndexedSubscript:(NSUInteger)index;

@end
