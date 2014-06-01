//
//  BFWQueryTests.m
//  BFWQueryTests
//
//  Created by Tom Brodhurst-Hill on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BFWQuery.h"
#import "BFWCountries.h"

@interface BFWQueryTests : XCTestCase

@property (nonatomic, strong) BFWCountries* countries;
@property (nonatomic, strong) BFWQuery* referenceQuery;
@property (nonatomic, assign) double referenceInterval;

@end

@implementation BFWQueryTests

- (BFWCountries*)countries
{
	if (!_countries) {
		_countries = [[BFWCountries alloc] init];
	}
	return _countries;
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testCaseInsensitiveKeysInQuery
{
	BFWQuery* query = [self.countries queryForAllCountries];
	for (NSDictionary* countryDict in query.resultArray) {
		BOOL isCaseInsensitiveKeys = [countryDict[@"name"] isEqualToString:countryDict[@"Name"]];
		if (!isCaseInsensitiveKeys) {
			XCTFail(@"Failed test \"%s\"", __PRETTY_FUNCTION__);
			break;
		}
	}
}

- (void)testInsertAndCount
{
	NSString* databasePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"TestDatabase.sqlite"];
	BFWDatabase* database = [BFWDatabase databaseWithPath:databasePath];
	BOOL success = [database open];
	if (success) {
		success = [database beginImmediateTransaction];
		if (success) {
			NSString* createTableSql = @""
			"create table Test\n"
			"(	ID integer primary key not null\n"
			",	Name text not null\n"
			",	Row integer\n"
			")";
			success = [database executeUpdate:createTableSql];
            NSUInteger rowCount = 300000;
			if (success) {
				for (int rowN = 0; rowN < rowCount; rowN++) {
					if (success) {
						success = [database insertIntoTable:@"Test"
													rowDict:@{@"Name":@"Tom",
															  @"Row":@(rowN + 1)
															  }];
					} else {
						break;
					}
				}
			}
			if (success) {
				BFWQuery* query = [[BFWQuery alloc] initWithDatabase:database
															   table:@"Test"
															 columns:@[@"ID", @"Name", @"Row"]
														   whereDict:@{@"Name": @"Tom"}];
				NSLog(@"BFWQuery rowCount start");
				NSUInteger rowCount = [query rowCount];
				NSLog(@"BFWQuery rowCount end. rowCount = %lu", (unsigned long)rowCount);
				BFWQuery* countQuery = [[BFWQuery alloc] initWithDatabase:database
															  queryString:@"select count(*) as Count from Test where Name = ?"
																arguments:@[@"Tom"]];
				NSLog(@"count(*) start");
				NSNumber* starCount = [[countQuery resultArray] firstObject][@"Count"];
				NSLog(@"count(*) end. Count = %ld", (long)[starCount integerValue]);
                
                self.referenceInterval = 0;
                self.referenceQuery = query;
                
                [self speedTestSummary:@"*[query.resultSet stringForColumnIndex:1] next reference"
                                 block:^{
                                     while ([query.resultSet next]) {
                                         NSString* name = [query.resultSet stringForColumnIndex:1];
                                     }
                                 }];
                
                [self speedTestSummary:@"*[query.resultSet stringForColumnIndex:1] next"
                                 block:^{
                                     while ([query.resultSet next]) {
                                         NSString* name = [query.resultSet stringForColumnIndex:1];
                                     }
                                 }];
                
                [self speedTestSummary:@" [query.resultSet stringForColumnIndex:1] currentRow"
                                 block:^{
                                     for (NSInteger rowN = 0; rowN < rowCount; rowN++) {
                                         query.currentRow = rowN;
                                         NSString* name = [query.resultSet stringForColumnIndex:1];
                                     }
                                 }];
                
                [self speedTestSummary:@" [query.resultSet stringForColumnIndex:[columnNames indexOfObject]]"
                                 block:^{
                                     NSArray* columnNames = [query columnNames];
                                     while ([query.resultSet next]) {
                                         NSUInteger columnIndex = [columnNames indexOfObject:@"Name"];
                                         NSString* name = [query.resultSet stringForColumnIndex:(int)columnIndex];
                                     }
                                 }];
                
                [self speedTestSummary:@" [query objectAtRow:rowN columnIndex:1]"
                                 block:^{
                                     for (NSInteger rowN = 0; rowN < rowCount; rowN++) {
                                         NSString* name = [query objectAtRow:rowN columnIndex:1];
                                     }
                                 }];
                
                [self speedTestSummary:@" [query objectAtRow:rowN columnName:@\"Name\"]"
                                 block:^{
                                     for (NSInteger rowN = 0; rowN < rowCount; rowN++) {
                                         NSString* name = [query objectAtRow:rowN columnName:@"Name"];
                                     }
                                 }];
                
                [self speedTestSummary:@" [query.resultSet stringForColumn:@\"Name\"]"
                                 block:^{
                                     while ([query.resultSet next]) {
                                         NSString* name = [query.resultSet stringForColumn:@"Name"];
                                     }
                                 }];
                
                [self speedTestSummary:@" rowDict[1]"
                                 block:^{
                                     for (BFWResultDictionary* rowDict in query.resultArray) {
                                         NSString* name = rowDict[1];
                                     }
                                 }];
                
                [self speedTestSummary:@" rowDict[@\"Name\"]"
                                 block:^{
                                     for (NSDictionary* rowDict in query.resultArray) {
                                         NSString* name = rowDict[@"Name"];
                                     }
                                 }];
                
                [self speedTestSummary:@"*[query.resultSet stringForColumnIndex:1] next"
                                 block:^{
                                     while ([query.resultSet next]) {
                                         NSString* name = [query.resultSet stringForColumnIndex:1];
                                     }
                                 }];
                
			}
			if (!success) {
				XCTFail(@"Failed test \"%s\", SQL error: %@", __PRETTY_FUNCTION__, database.lastErrorMessage);
			}
			[database rollback];
		} else {
			XCTFail(@"Failed test \"%s\", SQL error: %@", __PRETTY_FUNCTION__, database.lastErrorMessage);
		}
	} else {
		XCTFail(@"Failed test \"%s\", could not open database", __PRETTY_FUNCTION__);
	}
}

- (void)speedTestSummary:(NSString*)summary
                   block:(void (^)(void))block
{
    [self.referenceQuery reload];
    NSDate* startDate = [NSDate date];
    block();
    double elapsedInterval = -[startDate timeIntervalSinceNow];
    if (!self.referenceInterval) {
        self.referenceInterval = elapsedInterval;
    }
    NSLog(@"elapsed = %lf  %@", elapsedInterval / self.referenceInterval, summary);
}

- (void)testSpeed
{
    
}

@end
