//
//  BFWMasterViewController.m
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

#import "BFWMasterViewController.h"
#import "BFWCountries.h"
#import "BFWQuery.h"

@interface BFWMasterViewController ()

@property (nonatomic, strong) BFWCountries* countries;
@property (nonatomic, strong) BFWQuery* query;

@end

@implementation BFWMasterViewController

#pragma mark - accessors

- (BFWCountries*)countries
{
	if (!_countries) {
		_countries = [[BFWCountries alloc] init];
	}
	return _countries;
}

- (BFWQuery*)query
{
	if (!_query) {
		_query = [self.countries queryForAllCountries];
	}
	return _query;
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.query.resultArray count];
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

	cell.textLabel.text = self.query.resultArray[indexPath.row][@"Name"];
	cell.detailTextLabel.text = self.query.resultArray[indexPath.row][@"Code"];
    return cell;
}

@end
