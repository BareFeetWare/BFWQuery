//
//  BFWQuery.m
//
//  Created by Tom Brodhurst-Hill on 8/09/13.
//  Copyright (c) 2013 BareFeetWare. All rights reserved.
//

#import "BFWQuery.h"
#import "FMResultSet.h"

@implementation NSArray (BFWQuery)

- (NSString*)componentsJoinedByString:(NSString *)separator
								quote:(NSString*)quote
{
    NSMutableArray* mutableArray = [NSMutableArray array];
    for (NSString* component in self) {
        NSString* quotedString = [@[quote, component, quote] componentsJoinedByString:@""];
        [mutableArray addObject:quotedString];
    }
    return [mutableArray componentsJoinedByString:separator];
}

- (NSUInteger)indexOfCaseInsensitiveString:(NSString*)string
{
    NSUInteger matchedIndex = [self indexOfObject:string];
    if (matchedIndex == NSNotFound) {
        for (NSUInteger index = 0; index < [self count]; index++) {
            NSString* object = self[index];
            if ([string compare:(NSString*)object options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                matchedIndex = index;
                break;
            }
        }
    }
    return matchedIndex;
}

@end

@implementation NSDictionary (BFWQuery)

- (id)objectForCaseInsensitiveKey:(id)key
{
    id object = self[key];
    if (!object && [key isKindOfClass:[NSString class]]) {
        for (NSString* myKey in [self allKeys]) {
            if ([myKey compare:key options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                object = self[myKey];
                break;
            }
        }
    }
    return object;
}

- (NSDictionary*)dictionaryWithValuesForKeyPathMap:(NSDictionary*)columnKeyPathMap
{
	NSMutableDictionary* rowDict = [NSMutableDictionary dictionary];
	for (NSString* columnName in columnKeyPathMap) {
		id nestedItem = self;
        NSString* keyPath = columnKeyPathMap[columnName];
		for (NSString* key in [keyPath componentsSeparatedByString:@"."]) {
			if ([@"0123456789" rangeOfString:key].location != NSNotFound) { // TODO: more robust check for number, eg if > 9
				NSUInteger index = [key integerValue];
				nestedItem = nestedItem[index];
			} else {
				nestedItem = [nestedItem objectForCaseInsensitiveKey:key];
            }
		}
		if (nestedItem) {
			rowDict[columnName] = nestedItem;
		}
	}
	return [NSDictionary dictionaryWithDictionary:rowDict];
}

// Similar to dictionaryWithValuesForKeys except keys are case insensitive and returns without null values
- (NSDictionary*)dictionaryWithValuesForExistingCaseInsensitiveKeys:(NSArray*)keys
{
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
	for (id key in keys) {
        id object = [self objectForCaseInsensitiveKey:key];
        if (object) {
            dictionary[key] = object;
        }
	}
	return [NSDictionary dictionaryWithDictionary:dictionary];
}

@end

@implementation BFWDatabase

#pragma mark transactions

- (BOOL)beginImmediateTransaction
{
    BOOL success = [self executeUpdate:@"begin immediate transaction"];
    if (success) {
        _inTransaction = YES;
    }
    return success;
}

#pragma mark open

- (BOOL)open
{
	BOOL success = [super open];
	if (success) {
		[self executeUpdate:@"pragma foreign_keys = ON"];
	}
	return success;
}

#pragma mark introspection

- (NSArray*)columnNamesInTable:(NSString*)tableName
{
	FMResultSet* resultSet = [self executeQuery:[NSString stringWithFormat:@"pragma table_info('%@')", tableName]];
	NSMutableArray* columnNameArray = [NSMutableArray array];
	while ([resultSet next]) {
		[columnNameArray addObject:resultSet[@"name"]];
	}
	return [NSArray arrayWithArray:columnNameArray];
}

#pragma mark insert, delete, update

- (BOOL)insertIntoTable:(NSString*)table
                rowDict:(NSDictionary*)rowDict
{
    return [self insertIntoTable:table rowDict:rowDict conflictAction:nil];
}

- (BOOL)insertIntoTable:(NSString *)table
                rowDict:(NSDictionary *)rowDict
         conflictAction:(NSString*)conflictAction
{
    NSString* insertString = @"insert";
    if (conflictAction) {
        insertString = [insertString stringByAppendingFormat:@" or %@", conflictAction]; // ignore or replace
    }
	NSDictionary* sqlDict = [[self class] sqlDictFromRowDict:rowDict assignListSeparator:nil];
	NSString* queryString = [NSString stringWithFormat:@"%@ into \"%@\" (%@) values (%@)", insertString, table, sqlDict[@"columns"], sqlDict[@"placeholders"]];
	BOOL success = [self executeUpdate:queryString withArgumentsInArray:sqlDict[@"arguments"]];
	return success;
}

- (BOOL)insertIntoTable:(NSString*)table
        sourceDictArray:(NSArray*)sourceDictArray
       columnKeyPathMap:(NSDictionary*)columnKeyPathMap
         conflictAction:(NSString*)conflictAction
{
	BOOL success = YES;
	NSArray* columns = [self columnNamesInTable:table];
#ifdef DEBUG
    NSMutableArray* missingColumns = [NSMutableArray arrayWithArray:[columnKeyPathMap allKeys]];
    for (NSString* tableColumn in columns) {
        for (NSString* mapColumn in missingColumns) {
            if ([[tableColumn lowercaseString] isEqualToString:[mapColumn lowercaseString]]) {
                [missingColumns removeObject:mapColumn];
                break;
            }
        }
    }
    if ([missingColumns count]) {
        NSLog(@"columnKeyPathMap contains columns: (%@) which aren't in the table: %@", [missingColumns componentsJoinedByString:@", "], table);
    }
#endif
	for (NSDictionary* sourceDict in sourceDictArray) {
		NSMutableDictionary* mutableDict = [NSMutableDictionary dictionaryWithDictionary:sourceDict];
		[mutableDict addEntriesFromDictionary:[sourceDict dictionaryWithValuesForKeyPathMap:columnKeyPathMap]];
        NSDictionary* rowDict = [mutableDict dictionaryWithValuesForExistingCaseInsensitiveKeys:columns];
		success = [self insertIntoTable:table
                                rowDict:rowDict
                         conflictAction:conflictAction];
		if (!success) {
			break;
		}
	}
	return success;
}

- (BOOL)deleteFromTable:(NSString*)table
              whereDict:(NSDictionary*)whereDict
{
	NSDictionary* whereSqlDict = [[self class] sqlDictFromRowDict:whereDict assignListSeparator:@" and "];
	NSString* queryString = [NSString stringWithFormat:@"delete from \"%@\" where %@", table, whereSqlDict[@"assign"]];
	BOOL success = [self executeUpdate:queryString withArgumentsInArray:whereSqlDict[@"arguments"]];
	return success;
}

- (BOOL)updateTable:(NSString*)table
            rowDict:(NSDictionary*)rowDict
		  whereDict:(NSDictionary*)whereDict
{
	NSDictionary* rowSqlDict = [[self class] sqlDictFromRowDict:rowDict assignListSeparator:@", "];
	NSDictionary* whereSqlDict = [[self class] sqlDictFromRowDict:whereDict assignListSeparator:@" and "];
	NSString* queryString = [NSString stringWithFormat:@"update \"%@\" set %@ where %@", table, rowSqlDict[@"assign"], whereSqlDict[@"assign"]];
	NSMutableArray* arguments = [NSMutableArray arrayWithArray:rowSqlDict[@"arguments"]];
	[arguments addObjectsFromArray:whereSqlDict[@"arguments"]];
	BOOL success = [self executeUpdate:queryString withArgumentsInArray:arguments];
	return success;
}

#pragma mark SQL construction

+ (NSString*)placeholdersStringForCount:(NSUInteger)count
{
	NSMutableArray* placeholders = [NSMutableArray array];
	for (int placeholderN = 0; placeholderN < count; placeholderN++) {
		[placeholders addObject:@"?"];
	}
	NSString* placeholdersString = [placeholders componentsJoinedByString:@", "];
	return  placeholdersString;
}

+ (NSDictionary*)sqlDictFromRowDict:(NSDictionary*)rowDict
				assignListSeparator:(NSString*)assignListSeparator
{
	NSMutableArray* assignArray = [NSMutableArray array];
	NSMutableArray* arguments = [NSMutableArray array];
    NSArray* columnNames = rowDict.allKeys;
	for (NSString* columnName in rowDict.allKeys) {
		NSString* quotedColumnName = [NSString stringWithFormat:@"\"%@\"", columnName];
		NSString* assignString = [NSString stringWithFormat:@"%@ = ?", quotedColumnName];
		[assignArray addObject:assignString];
		[arguments addObject:rowDict[columnName]];
	}
	NSString* placeholdersString = [self placeholdersStringForCount:rowDict.allKeys.count];
	NSString* quotedColumnNamesString = [columnNames componentsJoinedByString:@", " quote:@"\""];
	NSMutableDictionary* sqlDict = [NSMutableDictionary dictionaryWithDictionary:@{@"columns" : quotedColumnNamesString, @"placeholders" : placeholdersString, @"arguments" : arguments}];
	if (assignListSeparator) {
		NSString* assignListString = [assignArray componentsJoinedByString:assignListSeparator];
		[sqlDict setObject:assignListString forKey:@"assign"];
	}
	return [NSDictionary dictionaryWithDictionary:sqlDict];
}

+ (NSString*)stringForValue:(id)value usingNullString:(NSString*)nullString quoteMark:(NSString*)quoteMark
{
	NSString* quotedQuote = [NSString stringWithFormat:@"%@%@", quoteMark, quoteMark];
	NSString* string = nil;
	if ([value isKindOfClass:[NSNull class]]) {
		string = nullString;
	} else if ([value isKindOfClass:[NSString class]]) {
		string = [value stringByReplacingOccurrencesOfString:quoteMark withString:quotedQuote];
		string = [NSString stringWithFormat:@"%@%@%@", quoteMark, string, quoteMark];
	} else if (value == nil) {
		string = @"?";
	} else { // need to cater for NSData to blob syntax
		string = [value description];
	}
	return string;
}

@end

@implementation FMResultSet (BFWQuery)

- (NSString*)columnTypeForIndex:(NSUInteger)index
{
	NSString* columnType;
	const char* columnTypeC = (const char *)sqlite3_column_decltype(self.statement.statement, (int)index);
	if(columnTypeC == nil) {
		columnType = @""; // TODO: get another way, such as sample rows or function type used in view
	} else {
		columnType = [NSString stringWithUTF8String:columnTypeC];
	}
	return columnType;
}

- (id)objectOrNilForColumnIndex:(int)columnIndex
{
    id returnObject = nil;
    int columnType = sqlite3_column_type([_statement statement], columnIndex);
    if (columnType == SQLITE_INTEGER) {
        returnObject = @([self longLongIntForColumnIndex:columnIndex]);
    } else if (columnType == SQLITE_FLOAT) {
        returnObject = @([self doubleForColumnIndex:columnIndex]);
    } else if (columnType == SQLITE_BLOB) {
        returnObject = [self dataForColumnIndex:columnIndex];
    } else {
        returnObject = [self stringForColumnIndex:columnIndex];
    }
    return returnObject;
}

@end

@interface BFWQuery ()

@property (nonatomic, strong, readwrite) FMResultSet* resultSet;
@property (nonatomic, assign, readwrite) NSInteger rowCount;
@property (nonatomic, strong, readwrite) NSArray* columnDictArray;
@property (nonatomic, strong, readwrite) NSArray* columnNames;

@property (nonatomic, assign) BOOL caching;
@property (nonatomic, assign) NSUInteger lastCacheRow;
@property (nonatomic, strong) BFWDatabase* cacheDatabase;
@property (nonatomic, readonly) NSString* cacheTableName;
@property (nonatomic, assign) BOOL isCacheTableCreated;

@end

@implementation BFWQuery

#pragma mark init

// Designated initializer:
- (instancetype)initWithDatabase:(BFWDatabase*)database
                     queryString:(NSString*)queryString
                       arguments:(NSArray*)arguments
{
	self = [super init];
	if (self) {
		_database = database;
		_queryString = queryString;
		_arguments = arguments;
		_currentRow = -1;
		_rowCount = -1;
	}
	return self;
}

- (instancetype)initWithDatabase:(BFWDatabase *)database table:(NSString*)tableName
{
	self = [self initWithDatabase:database table:tableName columns:nil whereDict:nil];
	return self;
}

- (instancetype)initWithDatabase:(BFWDatabase*)database
                           table:(NSString*)tableName
                         columns:(NSArray*)columnNames
                       whereDict:(NSDictionary*)whereDict
{
    NSString* whereString = @"";
    NSArray* arguments = nil;
    if ([whereDict count]) {
        NSDictionary* whereSqlDict = [BFWDatabase sqlDictFromRowDict:whereDict assignListSeparator:@" and "];
        whereString = [@" where " stringByAppendingString:whereSqlDict[@"assign"]];
        arguments = whereSqlDict[@"arguments"];
    }
    NSString* columnsString = @"*";
    if ([columnNames count]) {
        columnsString = [columnNames componentsJoinedByString:@", " quote:@"\""];
    }
    NSString* queryString = [NSString stringWithFormat:@"select %@ from \"%@\"%@", columnsString, tableName, whereString];
    self = [self initWithDatabase:database queryString:queryString arguments:arguments];
    if (self) {
        _tableName = tableName;
    }
    return self;
}

#pragma mark query

- (NSString*)sqlString
{
	NSArray* components = [self.queryString componentsSeparatedByString:@"?"];
	NSMutableArray* descriptionArray = [NSMutableArray array];
	for (int argumentN = 0; argumentN < self.arguments.count; argumentN++) {
		NSString* component = [components objectAtIndex:argumentN];
		[descriptionArray addObject:component];
		id argument = argumentN < [self.arguments count] ? [self.arguments objectAtIndex:argumentN] : nil;
		NSString* argumentString = [BFWDatabase stringForValue:argument usingNullString:@"null" quoteMark:@"'"];
		[descriptionArray addObject:argumentString];
	}
	[descriptionArray addObject:[components lastObject]];
	NSString* sqlString = [descriptionArray componentsJoinedByString:@""];
	return sqlString;
}

#pragma mark result set

- (FMResultSet*)resultSet
{
	if (!_resultSet) {
		_resultSet = [self.database executeQuery:self.queryString withArgumentsInArray:self.arguments];
	}
	return _resultSet;
}

- (void)setCurrentRow:(NSInteger)currentRow
{
	if (currentRow < _currentRow){
		[self resetStatement];
	}
	while (_currentRow < currentRow && [self.resultSet next]) {
		_currentRow++;
	}
}

- (NSInteger)rowCount
{
	if (_rowCount == -1) {
		while ([self.resultSet next]) {
			_currentRow++;
		}
		_rowCount = _currentRow + 1;
		[self resetStatement];
	}
	return _rowCount;
}

- (void)resetStatement
{
	[self.resultSet.statement reset];
	//TODO: why doesn't above work?
	self.resultSet = nil;
	_currentRow = -1;
}

- (void)reload
{
	self.rowCount = -1;
	[self resetStatement];
}

- (id)objectAtRow:(NSUInteger)row
      columnIndex:(NSUInteger)columnIndex
{
    id object = nil;
    if (row <= self.lastCacheRow) {
        BFWQuery* query = [[BFWQuery alloc] initWithDatabase:self.database
                                                       table:self.cacheTableName
                                                     columns:nil
                                                   whereDict:@{@"BFW_cache_row": @(row)}];
        object = [query objectAtRow:row columnIndex:columnIndex + 1];
    } else {
        if (self.caching) {
            //TODO: batch insert from select
            for (NSUInteger cacheRow = self.currentRow + 1; cacheRow < self.currentRow; cacheRow++) {
                NSMutableDictionary* rowDict = [self.resultSet.resultDictionary mutableCopy];
                rowDict[@"BFW_cache_row"] = @(row);
                [self createCacheTable];
                [self.database insertIntoTable:self.cacheTableName
                                       rowDict:rowDict];
            }
            self.lastCacheRow = self.currentRow;
        }
        self.currentRow = row;
        object = [self.resultSet objectOrNilForColumnIndex:(int)columnIndex];
    }
	return object;
}

- (id)objectAtRow:(NSUInteger)row
       columnName:(NSString*)columnName
{
    id object = nil;
    NSUInteger columnIndex = [self.columnNames indexOfCaseInsensitiveString:columnName];
    if (columnIndex != NSNotFound) {
        object = [self objectAtRow:row
                       columnIndex:columnIndex];
    }
	return object;
}

- (BFWResultArray*)resultArray
{
	if (!_resultArray) {
		_resultArray = [[BFWResultArray alloc] initWithQuery:self];
	}
	return _resultArray;
}

#pragma mark introspection

- (NSUInteger)columnCount
{
	return [self.resultSet columnCount];
}

- (NSArray*)columnDictArray
{
	if (!_columnDictArray) {
		NSMutableArray* columnDictArray = [NSMutableArray array];
		for (int columnN = 0; columnN < self.resultSet.columnCount; columnN++) {
			NSString* columnType = [self.resultSet columnTypeForIndex:columnN];
			NSMutableDictionary* columnDict = [NSMutableDictionary dictionaryWithObject:[self.resultSet columnNameForIndex:columnN] forKey:@"name"];
			if (columnType.length) {
				[columnDict setObject:columnType forKey:@"type"];
			}
			[columnDictArray addObject:[NSDictionary dictionaryWithDictionary:columnDict]];
		}
		_columnDictArray = [[NSArray alloc] initWithArray:columnDictArray];
	}
	return _columnDictArray;
}

- (NSArray*)columnNames
{
    if (!_columnNames) {
        NSMutableArray* columnNames = [NSMutableArray array];
        for (NSDictionary* columnDict in self.columnDictArray) {
            [columnNames addObject:columnDict[@"name"]];
        }
        _columnNames = [columnNames copy];
    }
    return _columnNames;
}

#pragma mark caching

- (BFWDatabase*)cacheDatabase // different database connection since different resultSet
{
	if (!_cacheDatabase) {
		_cacheDatabase = [[BFWDatabase alloc] initWithPath:self.database.databasePath];
		[_cacheDatabase open];
	}
	return _cacheDatabase;
}

- (NSString*)cacheTableName
{
	NSString* cacheTableName = [NSString stringWithFormat:@"BFW Cache %@", [self.queryString stringByReplacingOccurrencesOfString:@"\"" withString:@""]];
	return cacheTableName;
}

- (void)createCacheTable
{
    if (!self.isCacheTableCreated) {
        NSMutableArray* columnSchemas = [NSMutableArray array];
        [columnSchemas addObject:@"BFW_cache_row integer primary key not null"];
        for (NSDictionary* columnDict in self.columnDictArray) {
            NSString* columnSchema = columnDict[@"name"];
            if (columnDict[@"type"]) {
                columnSchema = [columnSchema stringByAppendingFormat:@" %@", columnDict[@"type"]];
            }
            [columnSchemas addObject:columnSchema];
        }
        [self.database executeQueryWithFormat:@"create temp table \"%@\"\n(\t%@\n)", self.cacheTableName, [columnSchemas componentsJoinedByString:@"\n,\t"]];
        self.isCacheTableCreated = YES;
    }
}

//TODO: Finish implementing caching for backwards scrolling

#pragma mark NSObject

- (NSString*)description
{
	NSString* description = [self sqlString];
	if (!description) {
		description = [super description];
	}
	return description;
}

@end

@interface BFWResultArray ()

@end

@implementation BFWResultArray

#pragma mark BFWResultArray

- (instancetype)initWithQuery:(BFWQuery*)query
{
	self = [super init];
	if (self) {
		_query = query;
	}
	return self;
}

- (NSUInteger)columnCount
{
	return [self.query columnCount];
}

- (BFWResultDictionary*)objectAtRow:(NSUInteger)row
{
	BFWResultDictionary* resultDictionary = [[BFWResultDictionary alloc] initWithResultArray:self row:row];
	return resultDictionary;
}

#pragma mark NSArray

- (NSDictionary*)objectAtIndex:(NSUInteger)index
{
	return [self objectAtRow:index];
}

- (NSUInteger)count
{
	return self.query.rowCount;
}

@end

@interface BFWResultDictionaryEnumerator : NSEnumerator

@property (nonatomic, strong) BFWResultDictionary* resultDictionary;
@property (nonatomic, assign) NSInteger columnN;

@end

@implementation BFWResultDictionaryEnumerator

- (instancetype)initWithResultDictionary:(BFWResultDictionary*)resultDictionary
{
	self = [super init];
	if (self) {
		_resultDictionary = resultDictionary;
	}
	return self;
}

- (id)nextObject
{
	id nextObject = nil;
	if (self.columnN < [self.resultDictionary.allKeys count]) {
		nextObject = self.resultDictionary.allKeys[self.columnN];
		self.columnN++;
	}
	return nextObject;
}

@end

@interface BFWResultDictionary ()

@property (nonatomic, strong) NSArray* allKeys;

@end

@implementation BFWResultDictionary

#pragma mark BFWResultDictionary

- (instancetype)initWithResultArray:(BFWResultArray*)resultArray
								row:(NSUInteger)row
{
	self = [super init];
	if (self) {
		_resultArray = resultArray;
		_row = row;
	}
	return self;
}

- (id)objectAtIndex:(NSUInteger)index
{
	id object = [self.resultArray.query objectAtRow:self.row
                                        columnIndex:index];
	return object;
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	return [self objectAtIndex:index];
}

#pragma mark NSDictionary

- (id)objectForKey:(id)key
{
	id object = [self.resultArray.query objectAtRow:self.row
                                         columnName:key];
	return object;
}

- (NSArray*)allKeys
{
	if (!_allKeys) {
		NSMutableArray* allKeys = [NSMutableArray array];
		NSArray* columnNames = [self.resultArray.query columnNames];
		for (NSUInteger columnIndex = 0; columnIndex < [columnNames count]; columnIndex++) {
			id object = [self.resultArray.query objectAtRow:self.row
                                                columnIndex:columnIndex];
			if (object) {
				[allKeys addObject:columnNames[columnIndex]];
			}
		}
		_allKeys = [allKeys copy];
	}
	return _allKeys;
}

- (NSUInteger)count // count the non null/nil values
{
	return [self.allKeys count];
}

- (BFWResultDictionaryEnumerator*)keyEnumerator
{
	return [[BFWResultDictionaryEnumerator alloc] initWithResultDictionary:self];
}

@end
