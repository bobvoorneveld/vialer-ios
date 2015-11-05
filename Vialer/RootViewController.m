//
//  RootViewController.m
//  Vialer
//
//  Created by Bob Voorneveld on 06/10/15.
//  Copyright © 2015 VoIPGRID. All rights reserved.
//
#import "RootViewController.h"

#import "ConnectionHandler.h"
#import "ContactsViewController.h"
#import "GAITracker.h"
#import "LogInViewController.h"
#import "RecentsViewController.h"
#import "SideMenuViewController.h"
#import "SIPCallingViewController.h"
#import "SIPIncomingViewController.h"
#import "SystemUser.h"
#import "TwoStepCallingViewController.h"

@interface RootViewController ()
@property (nonatomic, strong) SIPCallingViewController *sipCallingViewController;
@property (nonatomic, strong) SIPIncomingViewController *sipIncomingViewController;
@property (nonatomic, strong) SideMenuViewController *sideMenuViewController;
@property (nonatomic, strong) TwoStepCallingViewController *twoStepCallingViewController;
@property (nonatomic, strong) UINavigationController *contactsNavigationViewController;
@property (nonatomic, strong) UINavigationController *dialerNavigationController;
@property (nonatomic, strong) UINavigationController *recentsNavigationViewController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@end

@implementation RootViewController


#pragma mark - views setup

- (instancetype)init {
    self = [super init];

    if (self) {
        [self setRestorationIdentifier:@"MMDrawer"];
        [self setMaximumLeftDrawerWidth:222.0];
        [self setOpenDrawerGestureModeMask:MMOpenDrawerGestureModeAll];
        [self setCloseDrawerGestureModeMask:MMCloseDrawerGestureModeAll];
        [self setShadowRadius:2.f];
        [self setShadowOpacity:0.5f];
        [self setCenterViewController:self.tabBarController];
        [self setLeftDrawerViewController:self.sideMenuViewController];
    }
    return self;
}

- (SideMenuViewController *)sideMenuViewController {
    if (!_sideMenuViewController) {
        _sideMenuViewController = [[SideMenuViewController alloc] init];
    }
    return _sideMenuViewController;
}

- (SIPCallingViewController *)sipCallingViewController {
    if (!_sipCallingViewController) {
        _sipCallingViewController = [[SIPCallingViewController alloc] initWithNibName:@"SIPCallingViewController" bundle:[NSBundle mainBundle]];
        _sipCallingViewController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    }
    return _sipCallingViewController;
}

- (SIPIncomingViewController *)sipIncomingViewController {
    if (!_sipIncomingViewController) {
        _sipIncomingViewController = [[SIPIncomingViewController alloc] initWithNibName:@"SIPIncomingViewController" bundle:[NSBundle mainBundle]];
        _sipIncomingViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return _sipIncomingViewController;
}

- (UITabBarController *)tabBarController {
    if (!_tabBarController) {
        _tabBarController = [[UITabBarController alloc] init];
        _tabBarController.tabBar.translucent = NO;
        _tabBarController.viewControllers = @[ self.dialerNavigationController, self.contactsNavigationViewController, self.recentsNavigationViewController ];
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"MobileNumber"]) {
            self.tabBarController.selectedIndex = 1;    // Contacts
        }
    }
    return _tabBarController;
}

- (UINavigationController *)contactsNavigationViewController {
    if(!_contactsNavigationViewController) {
        ContactsViewController *contactsViewController = [[ContactsViewController alloc] init];
        _contactsNavigationViewController = [[UINavigationController alloc] initWithRootViewController:contactsViewController];
        _contactsNavigationViewController.navigationBar.translucent = NO;
    }
    return _contactsNavigationViewController;
}

- (UINavigationController *)dialerNavigationController {
    if (!_dialerNavigationController) {
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"CallingStoryboard" bundle:nil];
        UIViewController *dialerViewController = [sb instantiateViewControllerWithIdentifier:@"DailerViewController"];
        _dialerNavigationController = [[UINavigationController alloc] initWithRootViewController:dialerViewController];
        _dialerNavigationController.navigationBar.translucent = NO;
    }
    return _dialerNavigationController;
}

- (UINavigationController *)recentsNavigationViewController {
    if (!_recentsNavigationViewController) {
        UIViewController *recentsViewController = [[RecentsViewController alloc] initWithNibName:@"RecentsViewController" bundle:[NSBundle mainBundle]];
        recentsViewController.view.backgroundColor = [UIColor clearColor];
        _recentsNavigationViewController = [[UINavigationController alloc] initWithRootViewController:recentsViewController];
        _recentsNavigationViewController.navigationBar.translucent = NO;

    }
    return _recentsNavigationViewController;
}

- (TwoStepCallingViewController *)twoStepCallingViewController {
    if (!_twoStepCallingViewController) {
        _twoStepCallingViewController = [[TwoStepCallingViewController alloc] initWithNibName:@"TwoStepCallingViewController" bundle:[NSBundle mainBundle]];
    }
    return _twoStepCallingViewController;
}

#pragma mark - Handle calls

- (void)handlePhoneNumber:(NSString *)phoneNumber forContact:(NSString *)contact {

    if ([[ConnectionHandler sharedConnectionHandler] sipOutboundCallPossible]) {
        [GAITracker setupOutgoingSIPCallEvent];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.sipCallingViewController handlePhoneNumber:phoneNumber forContact:contact];
        });
    } else {
        [GAITracker setupOutgoingConnectABCallEvent];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.twoStepCallingViewController handlePhoneNumber:phoneNumber forContact:contact];
        });
    }
}

- (void)handleSipCall:(GSCall *)sipCall {
    return [self.sipCallingViewController handleSipCall:sipCall];
}

@end
