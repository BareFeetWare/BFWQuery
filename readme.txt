BFWQuery

(c) 2010-2014 BareFeetWare
Tom Brodhurst-Hill
developer@barefeetware.com

Objectives:

1. Make the power of SQLite available to Cocoa developers as simple as accessing arrays.

2. Internally manage

Usage:

1. Instantiate a database connection, eg:

@property (nonatomic, strong) BFWDatabase* database;

- (BFWDatabase*)database
{
	if (!_database) {
		_database = [[BFWDatabase alloc] initWithPath:databasePath];
		[_database open];
	}
	return _database;
}

2. Create a query, eg:

BFWQuery* query = [[BFWQuery alloc] initWithDatabase:self.database
								  queryString:@"select * from Country order by Name where Name = ?"
									arguments:@[countryName]];

3. Access rows of the result array:

To get the number of rows in the result array:

[query.resultArray count]

To get row 4, value in column "Name":

query.resultArray[4][@"Name"]

