//
//  AvailabilityViewController.h
//  Vialer
//
//  Created by Redmer Loen on 15-09-15.
//  Copyright (c) 2015 VoIPGRID. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AvailabilityViewController;
@protocol AvailabilityViewControllerDelegate <NSObject>
- (void)availabilityViewController:(AvailabilityViewController *)controller availabilityHasChanged:(NSArray *)availabilityOptions;
@end

@interface AvailabilityViewController : UITableViewController

@property (weak, nonatomic) id <AvailabilityViewControllerDelegate> delegate;
@end
