BFWQuery

(c) 2010-2014 BareFeetWare
Tom Brodhurst-Hill
developer@barefeetware.com

Objectives:

1. Makes the power of SQLite available to Cocoa developers as simple as accessing arrays. Initialise a query, then get its resultArray.

2. Internally manages the array without storing all rows in RAM. BFWQuery creates the objects within a row lazily, when requested. So, whether your query resultArray is 10 rows or 10,000 rows, it shouldn’t take noticeably more memory.

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


Requirements:

1. In Xcode, add lybsqlite to your project’s list of frameworks.

2. Add the BFWQuery.h and BFWQuery.m files to your project.

3. Add FMDB to your project, either the source files or the binary.

4. Works on iOS6 and later. It probably also works on iOS 5 and Mac OS X, but not tested.


License:

Use as you like, but keep the (c) BareFeetWare in the header and include “Includes BFWQuery class by BareFeetWare” in your app’s info panel or credits.

Many thanks to Gus Mueller for FMDB and Dr Richard Hipp for SQLite.