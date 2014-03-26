//
//  BFWDetailViewController.h
//  BFWQuery
//
//  Created by Tom on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BFWDetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) id detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
