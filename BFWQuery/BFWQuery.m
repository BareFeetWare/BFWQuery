//
//  BFWQuery.m
//
//  Created by Tom Brodhurst-Hill on 8/09/13.
//  Copyright (c) 2013 BareFeetWare. All rights reserved.
//

#import "BFWQuery.h"
#import "FMResultSet.h"

@implementation NSArray (BFWQuery)

- (NSString*)componentsJoinedByString:(NSString *)separator quote:(NSString*)quote
{
    NSMutableArray* mutableArray = [NSMutableArray array];
    for (NSString* component in self) {
        NSString* quotedString = [@[quote, component, quote] componentsJoinedByString:@""];
        [mutableArray addObject:quotedString];
    }
    return [mutableArray componentsJoinedByString:separator];
}

@end

@implementation NSDictionary (BFWQuery)

- (NSDictionary*)dictionaryWithValuesForKeyPathMap:(NSDictionary*)columnKeyPathMap
{
	NSMutableDictionary* rowDict = [NSMutableDictionary dictionary];
	for (NSString* columnName in columnKeyPathMap) {
		id nestedItem = self;
		for (NSString* key in [columnKeyPathMap[columnName] componentsSeparatedByString:@"."]) {
			if ([@"0123456789" rangeOfString:key].location != NSNotFound) { // TODO: more robust check for number
				NSUInteger index = [key integerValue];
				nestedItem = nestedItem[index];
			} else {
				nestedItem = nestedItem[key];
			}
		}
		if (nestedItem) {
			rowDict[columnName] = nestedItem;
		}
	}
	return [NSDictionary dictionaryWithDictionary:rowDict];
}

- (NSDictionary*)dictionaryByRemovingNulls
{
	NSMutableDictionary* dictionaryWithoutNulls = [NSMutableDictionary dictionary];
	for (id key in self) {
		if (self[key] != [NSNull null]) {
			dictionaryWithoutNulls[key] = self[key];
		}
	}
	return [NSDictionary dictionaryWithDictionary:dictionaryWithoutNulls];
}

- (NSDictionary*)dictionaryWithValuesForExistingKeys:(NSArray*)keys
{
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
	for (id key in keys) {
		if (self[key]) {
			dictionary[key] = self[key];
		}
	}
	return [NSDictionary dictionaryWithDictionary:dictionary];
}

@end

@implementation BFWDatabase

#pragma mark - open

- (BOOL)open
{
	BOOL success = [super open];
	if (success)
	{
		[self executeUpdate:@"pragma foreign_keys = ON"];
	}
	return success;
}

#pragma mark - introspection

- (NSArray*)columnNamesInTable:(NSString*)tableName
{
	FMResultSet* resultSet = [self executeQuery:[NSString stringWithFormat:@"pragma table_info('%@')", tableName]];
	NSMutableArray* columnNameArray = [NSMutableArray array];
	while ([resultSet next]) {
		[columnNameArray addObject:resultSet[@"name"]];
	}
	return [NSArray arrayWithArray:columnNameArray];
}

#pragma mark - insert, delete, update

- (BOOL)insertIntoTable:(NSString*)table rowDict:(NSDictionary*)rowDict
{
	NSDictionary* sqlDict = [self.class sqlDictFromRowDict:rowDict assignListSeparator:nil];
	NSString* queryString = [NSString stringWithFormat:@"insert into \"%@\" (%@) values (%@)", table, sqlDict[@"columns"], sqlDict[@"placeholders"]];
	BOOL success = [self executeUpdate:queryString withArgumentsInArray:sqlDict[@"arguments"]];
	return success;
}

- (BOOL)deleteFromTable:(NSString*)table whereDict:(NSDictionary*)whereDict
{
	NSDictionary* whereSqlDict = [self.class sqlDictFromRowDict:whereDict assignListSeparator:@" and "];
	NSString* queryString = [NSString stringWithFormat:@"delete from \"%@\" where %@", table, whereSqlDict[@"assign"]];
	BOOL success = [self executeUpdate:queryString withArgumentsInArray:whereSqlDict[@"arguments"]];
	return success;
}

- (BOOL)updateTable:(NSString*)table rowDict:(NSDictionary*)rowDict where:(NSDictionary*)whereDict
{
	NSDictionary* rowSqlDict = [self.class sqlDictFromRowDict:rowDict assignListSeparator:@", "];
	NSDictionary* whereSqlDict = [self.class sqlDictFromRowDict:whereDict assignListSeparator:@" and "];
	NSString* queryString = [NSString stringWithFormat:@"update \"%@\" set %@ where %@", table, rowSqlDict[@"assign"], whereSqlDict[@"assign"]];
	NSMutableArray* arguments = [NSMutableArray arrayWithArray:rowSqlDict[@"arguments"]];
	[arguments addObjectsFromArray:whereSqlDict[@"arguments"]];
	BOOL success = [self executeUpdate:queryString withArgumentsInArray:arguments];
	return success;
}

- (BOOL)insertIntoTable:(NSString*)table sourceDictArray:(NSArray*)sourceDictArray columnKeyPathMap:(NSDictionary*)columnKeyPathMap
{
	BOOL success = YES;
	NSArray* columns = [self columnNamesInTable:table];
	for (NSDictionary* sourceDict in sourceDictArray)
	{
		NSMutableDictionary* rowDict = [NSMutableDictionary dictionaryWithDictionary:[sourceDict dictionaryWithValuesForExistingKeys:columns]];
		[rowDict addEntriesFromDictionary:[sourceDict dictionaryWithValuesForKeyPathMap:columnKeyPathMap]];
		success = [self insertIntoTable:table rowDict:rowDict];
		if (!success) {
			break;
		}
	}
	return success;
}

#pragma mark - SQL construction

+ (NSString*)placeholdersStringForCount:(NSUInteger)count
{
	NSMutableArray* placeholders = [NSMutableArray array];
	for (int placeholderN = 0; placeholderN < count; placeholderN++)
		[placeholders addObject:@"?"];
	NSString* placeholdersString = [placeholders componentsJoinedByString:@", "];
	return  placeholdersString;
}

+ (NSDictionary*)sqlDictFromRowDict:(NSDictionary*)rowDict assignListSeparator:(NSString*)assignListSeparator
{
	NSMutableArray* assignArray = [NSMutableArray array];
	NSMutableArray* arguments = [NSMutableArray array];
    NSArray* columnNames = rowDict.allKeys;
	for (NSString* columnName in rowDict.allKeys)
	{
		NSString* quotedColumnName = [NSString stringWithFormat:@"\"%@\"", columnName];
		NSString* assignString = [NSString stringWithFormat:@"%@ = ?", quotedColumnName];
		[assignArray addObject:assignString];
		[arguments addObject:rowDict[columnName]];
	}
	NSString* placeholdersString = [self placeholdersStringForCount:rowDict.allKeys.count];
	NSString* quotedColumnNamesString = [columnNames componentsJoinedByString:@", " quote:@"\""];
	NSMutableDictionary* sqlDict = [NSMutableDictionary dictionaryWithDictionary:@{@"columns" : quotedColumnNamesString, @"placeholders" : placeholdersString, @"arguments" : arguments}];
	if (assignListSeparator)
	{
		NSString* assignListString = [assignArray componentsJoinedByString:assignListSeparator];
		[sqlDict setObject:assignListString forKey:@"assign"];
	}
	return [NSDictionary dictionaryWithDictionary:sqlDict];
}

+ (NSString*)queryStringForDict:(NSDictionary*)queryDict
{
	NSMutableArray* components = [NSMutableArray array];
	[components addObject:@"select"];
	if ([queryDict[@"columns"] count])
	{
		NSMutableArray* columns = [NSMutableArray array];
		for (id column in queryDict[@"columns"])
		{
			NSString* columnString = nil;
			if ([column isKindOfClass:[NSDictionary class]] && [column count] == 1)
			{
				NSDictionary* columnDict = (NSDictionary*)column;
				NSString* columnAlias = columnDict.allKeys[0];
				columnString = [NSString stringWithFormat:@"%@ as \"%@\"", columnDict[columnAlias], columnAlias];
			}
			else if ([column isKindOfClass:[NSString class]])
			{
				columnString = column;
			}
			[columns addObject:column];
		}
		[components addObject:[columns componentsJoinedByString:@", "]];
	}
	if (queryDict[@"from"])
	{
		[components addObject:[NSString stringWithFormat:@"from \"%@\"", queryDict[@"from"]]];
	}
	if ([queryDict[@"where"] count])
	{
		NSString* whereString = [queryDict[@"where"] componentsJoinedByString:@" and "];
		[components addObject:[NSString stringWithFormat:@"where %@", whereString]];
	}
	NSString* queryString = [components componentsJoinedByString:@"\n"];
	return queryString;
}

+ (NSString*)stringForValue:(id)value usingNullString:(NSString*)nullString quoteMark:(NSString*)quoteMark
{
	NSString* quotedQuote = [NSString stringWithFormat:@"%@%@", quoteMark, quoteMark];
	NSString* string = nil;
	if ([value isKindOfClass:[NSNull class]])
		string = nullString;
	else if ([value isKindOfClass:[NSString class]])
	{
		string = [value stringByReplacingOccurrencesOfString:quoteMark withString:quotedQuote];
		string = [NSString stringWithFormat:@"%@%@%@", quoteMark, string, quoteMark];
	}
	else // need to cater for NSData to blob syntax
		string = [value description];
	return string;
}

@end

@interface BFWQuery ()

@property (nonatomic, strong, readwrite) FMResultSet* resultSet;
@property (nonatomic, assign, readwrite) NSInteger rowCount;
@property (nonatomic, strong, readwrite) NSArray* columns;

@property (nonatomic, strong) BFWDatabase* cacheDatabase;
@property (nonatomic, readonly) NSString* cacheQuotedTableName;

@end

@implementation FMResultSet (BFWQuery)

- (NSString*)columnTypeForIndex:(NSUInteger)index
{
	NSString* columnType;
	const char* columnTypeC = (const char *)sqlite3_column_decltype(self.statement.statement, (int)index);
	if(columnTypeC == nil)
		columnType = @""; // TODO: get another way, such as sample rows or function type used in view
	else
		columnType = [NSString stringWithUTF8String:columnTypeC];
	return columnType;
}

@end

@implementation BFWQuery

#pragma mark - init

// Designated initializer:
- (instancetype)initWithDatabase:(BFWDatabase*)database queryString:(NSString*)queryString arguments:(NSArray*)arguments
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
	self = [self initWithDatabase:database queryString:nil arguments:nil];
	if (self) {
		_tableName = tableName;
    }
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
    if (columnNames) {
        columnsString = [columnNames componentsJoinedByString:@", " quote:@"\""];
    }
    NSString* queryString = [NSString stringWithFormat:@"select %@ from \"%@\"%@", columnsString, tableName, whereString];
    self = [self initWithDatabase:database queryString:queryString arguments:arguments];
    if (self) {
        _tableName = tableName;
    }
    return self;
}

#pragma mark - result set

- (FMResultSet*)resultSet
{
	if (_resultSet == nil)
		_resultSet = [self.database executeQuery:self.queryString withArgumentsInArray:self.arguments];
	return _resultSet;
}

- (void)setCurrentRow:(NSInteger)currentRow
{
	if (currentRow < _currentRow)
	{
		[self resetStatement];
	}
	while (_currentRow < currentRow && [self.resultSet next])
		_currentRow++;
//	DLog(@"currentRow = %ld, rowDict = %@", (long)_currentRow, self.resultSet.resultDictionary);
}

- (NSInteger)rowCount
{
	if (_rowCount == -1)
	{
		while ([self.resultSet next])
			_currentRow++;
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

- (BFWResultArray*)resultArray
{
	if (!_resultArray) {
		_resultArray = [[BFWResultArray alloc] initWithQuery:self];
	}
	return _resultArray;
}

#pragma mark - caching

- (BFWDatabase*)cacheDatabase // different database connection since different resultSet
{
	if (_cacheDatabase == nil)
	{
		_cacheDatabase = [[BFWDatabase alloc] initWithPath:self.database.databasePath];
		[_cacheDatabase open];
	}
	return _cacheDatabase;
}

- (NSString*)cacheQuotedTableName
{
	NSString* cacheQuotedTableName = [NSString stringWithFormat:@"\"BFW Cache %@\"", [self.queryString stringByReplacingOccurrencesOfString:@"\"" withString:@""]];
	return cacheQuotedTableName;
}

//TODO: Finish implementing caching for backwards scrolling

#pragma mark - NSObject

- (NSString*)description
{
	NSString* description = nil;
	NSArray* components = [self.queryString componentsSeparatedByString:@"?"];
	if (components.count == self.arguments.count + 1)
	{
		NSMutableArray* descriptionArray = [NSMutableArray array];
		for (int argumentN = 0; argumentN < self.arguments.count; argumentN++)
		{
			NSString* component = [components objectAtIndex:argumentN];
			[descriptionArray addObject:component];
			id argument = [self.arguments objectAtIndex:argumentN];
			NSString* argumentString = [self.class stringForValue:argument usingNullString:@"null" quoteMark:@"'"];
			[descriptionArray addObject:argumentString];
		}
		[descriptionArray addObject:[components lastObject]];
		description = [descriptionArray componentsJoinedByString:@""];
	}
	else
		description = [super description];
	return description;
}

@end

@interface BFWResultArray ()

@property (nonatomic, strong) BFWQuery* query;

@end

@implementation BFWResultArray

#pragma mark - BFWResultArray

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
	return [self.query.columns count];
}

- (NSDictionary*)objectAtQueryRow:(NSUInteger)queryRow
{
	self.query.currentRow = queryRow;
	return self.query.resultSet.resultDictionary;
}

- (id)objectAtQueryRow:(NSUInteger)queryRow columnName:(NSString*)columnName
{
	self.query.currentRow = queryRow;
	return [self.query.resultSet objectForColumnName:columnName];
}

#pragma mark - NSArray

- (NSDictionary*)objectAtIndex:(NSUInteger)index
{
	return [self objectAtQueryRow:index];
}

- (NSUInteger)count
{
	return self.query.rowCount;
}

@end
