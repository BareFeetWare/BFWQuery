//
//  BFWMasterViewController.h
//  BFWQuery
//
//  Created by Tom on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BFWDetailViewController;

@interface BFWMasterViewController : UITableViewController

@property (strong, nonatomic) BFWDetailViewController *detailViewController;

@end
