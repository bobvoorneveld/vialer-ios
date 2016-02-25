//
//  SIPIncomingCallViewController.m
//  Copyright © 2016 VoIPGRID. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>
#import "SIPCallingViewController.h"
#import "SIPIncomingCallViewController.h"
#import <VialerSIPLib-iOS/VSLRingtone.h>

static NSString * const SIPIncomingCallViewControllerShowSIPCallingSegue = @"SIPCallingSegue";
static NSString * const SIPIncomingCallViewControllerCallState = @"callState";
static NSString * const SIPIncomingCallViewControllerMediaState = @"mediaState";
static NSString * const SIPIncomingCallViewControllerRingtoneName = @"ringtone";
static NSString * const SIPIncomingCallViewControllerRingtoneExtension = @"wav";
static double const SIPIncomingCallViewControllerDismissTimeAfterHangup = 3.0;

static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

@interface SIPIncomingCallViewController()
@property (strong, nonatomic) VSLRingtone *ringtone;
@property (strong, nonatomic) NSString *phoneNumber;
@property (weak, nonatomic) IBOutlet UIButton *acceptCallButton;
@property (weak, nonatomic) IBOutlet UILabel *incomingCallStatusLabel;
@property (weak, nonatomic) IBOutlet UIButton *declineCallButton;
@property (weak, nonatomic) IBOutlet UILabel *incomingPhoneNumberLabel;
@end

@implementation SIPIncomingCallViewController

# pragma mark - Life cycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSString *labelText;
    if (self.call.callerName && self.call.callerNumber) {
        labelText = [NSString stringWithFormat:@"%@\n%@", self.call.callerName, self.call.callerNumber];
    } else if (self.call.callerName && !self.call.callerNumber) {
        labelText = [NSString stringWithFormat:@"%@", self.call.callerName];
    } else if (!self.call.callerName && self.call.callerNumber) {
        labelText = [NSString stringWithFormat:@"%@", self.call.callerNumber];
    } else {
        labelText = [NSString stringWithFormat:@"%@", self.call.remoteURI];
    }

    self.incomingPhoneNumberLabel.text = labelText;
    [self.ringtone start];
}

- (void)dealloc {
    [self.call removeObserver:self forKeyPath:SIPIncomingCallViewControllerCallState];
    [self.call removeObserver:self forKeyPath:SIPIncomingCallViewControllerMediaState];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[SIPCallingViewController class]]) {
        SIPCallingViewController *sipCallingViewController = (SIPCallingViewController *)segue.destinationViewController;
        [sipCallingViewController handleIncomingCallWithVSLCall:self.call];
    }
}

# pragma mark - properties

- (VSLRingtone *)ringtone {
    if (!_ringtone) {
        NSURL *fileUrl = [[NSBundle mainBundle] URLForResource:SIPIncomingCallViewControllerRingtoneName
                                                 withExtension:SIPIncomingCallViewControllerRingtoneExtension];
        _ringtone = [[VSLRingtone alloc] initWithRingtonePath:fileUrl];
    }
    return _ringtone;
}

- (void)setCall:(VSLCall *)call {
    if (_call) {
        [_call removeObserver:self forKeyPath:SIPIncomingCallViewControllerCallState];
        [_call removeObserver:self forKeyPath:SIPIncomingCallViewControllerMediaState];
    }
    _call = call;
    [call addObserver:self forKeyPath:SIPIncomingCallViewControllerCallState options:0 context:NULL];
    [call addObserver:self forKeyPath:SIPIncomingCallViewControllerMediaState options:0 context:NULL];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {

    if (object == self.call) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.call.callState == VSLCallStateDisconnected) {
                [self.ringtone stop];
                self.declineCallButton.enabled = NO;
                self.acceptCallButton.enabled = NO;

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SIPIncomingCallViewControllerDismissTimeAfterHangup * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self dismissViewControllerAnimated:NO completion:nil];
                });
            }
        });
    }
}

#pragma mark - IBActions

- (IBAction)declineCallButtonPressed:(UIButton * _Nonnull)sender {
    NSError *error;
    [self.call hangup:&error];
    if (error) {
        DDLogError(@"Error hangup call: %@", error);
    }

    self.incomingCallStatusLabel.text = NSLocalizedString(@"Declined call", nil);
}

- (IBAction)acceptCallButtonPressed:(UIButton * _Nonnull)sender {
    [self.ringtone stop];
    [self performSegueWithIdentifier:SIPIncomingCallViewControllerShowSIPCallingSegue sender:nil];
}

@end