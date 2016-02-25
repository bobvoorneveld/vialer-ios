//
//  APNSHandler.m
//  Copyright © 2016 voipgrid.com. All rights reserved.
//

#import "APNSHandler.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import "Middleware.h"
#import "SystemUser.h"

static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

@interface APNSHandler ()
@property (strong, nonatomic) PKPushRegistry *voipRegistry;
@property (strong, nonatomic) Middleware *middleware;
@end

@implementation APNSHandler

#pragma mark - Lifecycle
+ (instancetype)sharedHandler {
    static APNSHandler *sharedAPNSHandler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DDLogVerbose(@"Creating shared APNS Handler");
        sharedAPNSHandler = [[self alloc] init];
    });
    return sharedAPNSHandler;
}

#pragma mark - properties
- (PKPushRegistry *)voipRegistry {
    if (!_voipRegistry) {
        _voipRegistry = [[PKPushRegistry alloc] initWithQueue:nil];
    }
    return _voipRegistry;
}

- (Middleware *)middleware {
    if (!_middleware) {
        _middleware = [[Middleware alloc] init];
    }
    return _middleware;
}


#pragma mark - actions
- (void)registerForVoIPNotifications {
    // Only register once, if delegate is set, registration has been done before:
    if (!self.voipRegistry.delegate) {
        self.voipRegistry.delegate = self;

        DDLogVerbose(@"Initiating VoIP push registration");
        self.voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    }
}

+ (NSString *)storedAPNSToken {
    APNSHandler *sharedHandler = [[self class] sharedHandler];
    NSData *token = [sharedHandler.voipRegistry pushTokenForType:PKPushTypeVoIP];
    return [sharedHandler nsStringFromNSData:token];
}

#pragma mark - PKPushRegistray management
- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(NSString *)type {
    DDLogInfo(@"APNS Token became invalid");
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type {
    DDLogDebug(@"%s Incoming push notification of type: %@", __PRETTY_FUNCTION__, type);
    [self.middleware handleReceivedAPSNPayload:[payload dictionaryPayload]];
}

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
    DDLogInfo(@"Type:%@. APNS registration successful. Token: %@", type, credentials.token);
    [self.middleware sentAPNSToken:[self nsStringFromNSData:credentials.token]];
}

#pragma mark - token conversion
/*
 * Returns hexadecimal string of NSData. Empty string if data is empty.
 * http://stackoverflow.com/questions/1305225/best-way-to-serialize-a-nsdata-into-an-hexadeximal-string
 */
- (NSString *)nsStringFromNSData:(NSData *)data {
    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
    if (!dataBuffer)
        return nil;

    NSUInteger dataLength  = [data length];
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];

    for (int i = 0; i < dataLength; ++i) {
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }
    return [NSString stringWithString:hexString];
}

@end