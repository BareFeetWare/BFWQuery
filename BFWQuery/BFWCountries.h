//
//  BFWCountries.h
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BFWQuery;

@interface BFWCountries : NSObject

- (BFWQuery*)queryForAllCountries;
- (BFWQuery*)queryForCountriesContaining:(NSString*)searchString;

@end
