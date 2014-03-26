//
//  BFWCountries.m
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

#import "BFWCountries.h"
#import "BFWQuery.h"

@interface BFWCountries ()

@property (nonatomic, strong) BFWDatabase* database;

@end

@implementation BFWCountries

- (NSString*)databasePath
{
	return [[NSBundle mainBundle] pathForResource:@"Countries" ofType:@"sqlite"];
}

- (BFWDatabase*)database
{
	if (!_database) {
		_database = [[BFWDatabase alloc] initWithPath:[self databasePath]];
		[_database open];
	}
	return _database;
}

- (BFWQuery*)queryForAllCountries
{
	return [[BFWQuery alloc] initWithDatabase:self.database
								  queryString:@"select * from Country order by Name"
									arguments:nil];
}

- (BFWQuery*)queryForCountriesContaining:(NSString*)searchString
{
	return [[BFWQuery alloc] initWithDatabase:self.database
								  queryString:@"select * from Country where Name like '%%' || ? || '%%'"
									arguments:@[searchString]];
}

@end
