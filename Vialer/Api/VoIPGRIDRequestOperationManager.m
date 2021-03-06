//
//  VoIPGRIDRequestOperationManager.m
//  Copyright © 2015 VoIPGRID. All rights reserved.
//

#import "VoIPGRIDRequestOperationManager.h"

#import "Configuration.h"
#import "SAMKeychain.h"
#import "SystemUser.h"

static NSString * const VoIPGRIDRequestOperationManagerURLSystemUserProfile = @"permission/systemuser/profile/";
static NSString * const VoIPGRIDRequestOperationManagerURLUserDestination   = @"userdestination/";
static NSString * const VoIPGRIDRequestOperationManagerURLPhoneAccount      = @"phoneaccount/phoneaccount/";
static NSString * const VoIPGRIDRequestOperationManagerURLTwoStepCall       = @"mobileapp/";
static NSString * const VoIPGRIDRequestOperationManagerURLAutoLoginToken    = @"autologin/token/";
static NSString * const VoIPGRIDRequestOperationManagerURLMobileNumber      = @"permission/mobile_number/";
static NSString * const VoIPGRIDRequestOperationManagerURLMobileProfile     = @"mobile/profile/";

static NSString * const VoIPGRIDRequestOperationManagerApiKeyMobileNumber               = @"mobile_nr";
static NSString * const VoIPGRIDRequestOperationManagerApiKeyAppAccountUseEncryption    = @"appaccount_use_encryption";

static int const VoIPGRIDRequestOperationManagerTimoutInterval = 15;

NSString * const VoIPGRIDRequestOperationManagerErrorDomain = @"Vailer.VoIPGRIDRequestOperationManager";

NSString * const VoIPGRIDRequestOperationManagerUnAuthorizedNotification = @"VoIPGRIDRequestOperationManagerUnAuthorizedNotification";

@implementation VoIPGRIDRequestOperationManager

# pragma mark - Life cycle

- (instancetype)initWithBaseURL:(NSURL *)baseURL {
    return [self initWithBaseURL:baseURL andRequestOperationTimeoutInterval:VoIPGRIDRequestOperationManagerTimoutInterval];
}

- (instancetype)initWithDefaultBaseURL {
    NSURL *baseURL = [NSURL URLWithString:[[Configuration defaultConfiguration] UrlForKey:ConfigurationVoIPGRIDBaseURLString]];
    return [self initWithBaseURL:baseURL andRequestOperationTimeoutInterval:VoIPGRIDRequestOperationManagerTimoutInterval];
}

- (instancetype)initWithDefaultBaseURLandRequestOperationTimeoutInterval:(NSTimeInterval)requestTimeoutInterval {
    NSURL *baseURL = [NSURL URLWithString:[[Configuration defaultConfiguration] UrlForKey:ConfigurationVoIPGRIDBaseURLString]];
    return [self initWithBaseURL:baseURL andRequestOperationTimeoutInterval:requestTimeoutInterval];}

- (instancetype)initWithBaseURL:(NSURL *)baseURL andRequestOperationTimeoutInterval:(NSTimeInterval)requestTimeoutInterval {
    self = [super initWithBaseURL:baseURL];
    if (self) {
        self.requestSerializer = [AFJSONRequestSerializer serializer];
        [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        self.requestSerializer.timeoutInterval = requestTimeoutInterval;

        // Set basic authentication if user is logged in.
        NSString *user = [SystemUser currentUser].username;
        if (user) {
            NSString *password = [SAMKeychain passwordForService:[[self class] serviceName] account:user];
            [self.requestSerializer setAuthorizationHeaderFieldWithUsername:user password:password];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logoutUserNotification:) name:SystemUserLogoutNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Default authorized methods

- (AFHTTPRequestOperation *)GET:(NSString *)url parameters:parameters withCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    return [self createRequestWithUrl:url andMethod:@"GET" parameters:parameters withCompletion:completion];
}

- (AFHTTPRequestOperation *)PUT:(NSString *)url parameters:parameters withCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    return [self createRequestWithUrl:url andMethod:@"PUT" parameters:parameters withCompletion:completion];
}

- (AFHTTPRequestOperation *)POST:(NSString *)url parameters:parameters withCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    return [self createRequestWithUrl:url andMethod:@"POST" parameters:parameters withCompletion:completion];
}

- (AFHTTPRequestOperation *)DELETE:(NSString *)url parameters:parameters withCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    return [self createRequestWithUrl:url andMethod:@"DELETE" parameters:parameters withCompletion:completion];
}

- (AFHTTPRequestOperation *)createRequestWithUrl:(NSString *)url andMethod:(NSString *)method parameters:parameters withCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    url = [[NSURL URLWithString:url relativeToURL:self.baseURL] absoluteString];

    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:url parameters:parameters error:nil];
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
        completion(operation, responseObject, nil);
    } failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error) {
        /**
         *  Notify if the request was unauthorized.
         */
        if (operation.response.statusCode == VoIPGRIDHttpErrorUnauthorized) {
            [[NSNotificationCenter defaultCenter] postNotificationName:VoIPGRIDRequestOperationManagerUnAuthorizedNotification object:self];
        }
        completion(operation, nil, error);
    }];

    [self setHandleAuthorizationRedirectForRequest:request andOperation:operation];
    [self.operationQueue addOperation:operation];

    return operation;
}

- (void)setHandleAuthorizationRedirectForRequest:(NSURLRequest *)request andOperation:(AFHTTPRequestOperation *)operation {
    __block NSString *authorization = [request.allHTTPHeaderFields objectForKey:@"Authorization"];
    [operation setRedirectResponseBlock:^NSURLRequest *(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse) {
        if ([request.allHTTPHeaderFields objectForKey:@"Authorization"] != nil) {
            return request;
        }

        NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:request.URL cachePolicy:request.cachePolicy timeoutInterval:request.timeoutInterval];
        [urlRequest setValue:authorization forHTTPHeaderField:@"Authorization"];
        return urlRequest;
    }];
}

#pragma mark - SytemUser actions

- (void)loginWithUsername:(NSString *)username password:(NSString *)password withCompletion:(void (^)(NSDictionary *responseData, NSError *error))completion {
    [self.requestSerializer clearAuthorizationHeader];
    [self.requestSerializer setAuthorizationHeaderFieldWithUsername:username password:password];

    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"GET"
                                                                   URLString:[[NSURL URLWithString:VoIPGRIDRequestOperationManagerURLSystemUserProfile relativeToURL:self.baseURL] absoluteString]
                                                                  parameters:nil
                                                                       error:nil];
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (completion) {
            completion(responseObject, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSDictionary *userInfo = @{NSUnderlyingErrorKey: error,
                                   NSLocalizedDescriptionKey : NSLocalizedString(@"Login failed", nil)
                                   };
        completion(nil, [NSError errorWithDomain:VoIPGRIDRequestOperationManagerErrorDomain code:VoIPGRIDRequestOperationsManagerErrorLoginFailed userInfo:userInfo]);
    }];

    [self setHandleAuthorizationRedirectForRequest:request andOperation:operation];
    [self.operationQueue addOperation:operation];
}

- (void)getMobileProfileWithCompletion:(void(^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error)) completion {
    [self GET:VoIPGRIDRequestOperationManagerURLMobileProfile parameters:nil withCompletion: completion];
}

// I'm leaving this here for testing purposes. It gives the ability to simulate the user "not allowed to SIP case" without
// having to actually disable it in the portal (resulting in unlinking all app accounts for all users).
// Uncomment all below, put a breakpoint on line: [possibleModifiedResponseData setObject:[NSNumber numberWithBool:allowAppAccount] forKey:@"allow_app_account"];
// In the debug window you can change the value of allowAppAccount with "call allowAppAccount = YES/NO;"
//BOOL allowAppAccount = YES;
//- (void)userProfileWithCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
//    [self GET:VoIPGRIDRequestOperationManagerURLSystemUserProfile parameters:nil withCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error) {
//        NSMutableDictionary *possibleModifiedResponseData = [responseData mutableCopy];
//
//        if ([responseData objectForKey:@"allow_app_account"]) {
//            [possibleModifiedResponseData setObject:[NSNumber numberWithBool:allowAppAccount] forKey:@"allow_app_account"];
//        }
//        if (completion) {
//            completion(operation, possibleModifiedResponseData, error);
//        }
//    }];
//}

- (void)userProfileWithCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    [self GET:VoIPGRIDRequestOperationManagerURLSystemUserProfile parameters:nil withCompletion:completion];
}

- (void)pushMobileNumber:(NSString *)mobileNumber withCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *parameters = @{VoIPGRIDRequestOperationManagerApiKeyMobileNumber : mobileNumber};
    [self PUT:VoIPGRIDRequestOperationManagerURLMobileNumber parameters:parameters withCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error) {
        if (completion) {
            if (error) {
                completion(NO, error);
            } else {
                completion(YES, nil);
            }
        }
    }];
}

- (void)pushUseEncryptionWithCompletion:(void (^)(BOOL, NSError *))completion {
    NSDictionary *parameters = @{VoIPGRIDRequestOperationManagerApiKeyAppAccountUseEncryption : @YES};
    
    [self PUT:VoIPGRIDRequestOperationManagerURLMobileProfile parameters:parameters withCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error) {
        if (completion) {
            if (error) {
                completion(NO, error);
            } else {
                completion(YES, nil);
            }
        }
    }];
}

#pragma mark - Miscellaneous

- (void)autoLoginTokenWithCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    [self GET:VoIPGRIDRequestOperationManagerURLAutoLoginToken parameters:nil withCompletion:completion];
}

#pragma mark - SIP

- (void)retrievePhoneAccountForUrl:(NSString *)phoneAccountUrl withCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    phoneAccountUrl = [phoneAccountUrl stringByReplacingOccurrencesOfString:@"/api/" withString:@""];
    [self GET:phoneAccountUrl parameters:nil withCompletion:completion];
}

#pragma mark - User Destinations

- (void)userDestinationsWithCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    [self GET:VoIPGRIDRequestOperationManagerURLUserDestination parameters:nil withCompletion:completion];
}

- (void)pushSelectedUserDestination:(NSString *)selectedUserResourceUri destinationDict:(NSDictionary *)destinationDict withCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    [self PUT:selectedUserResourceUri parameters:destinationDict withCompletion:completion];
}

#pragma mark - TwoStepCall

- (void)setupTwoStepCallWithParameters:(NSDictionary *)parameters withCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    [self POST:VoIPGRIDRequestOperationManagerURLTwoStepCall parameters:parameters withCompletion:completion];
}

- (void)twoStepCallStatusForCallId:(NSString *)callId withCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    NSString *updateStatusURL = [NSString stringWithFormat:@"%@%@/", VoIPGRIDRequestOperationManagerURLTwoStepCall, callId];
    [self GET:updateStatusURL parameters:nil withCompletion:completion];
}

- (void)cancelTwoStepCallForCallId:(NSString *)callId withCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *responseData, NSError *error))completion {
    NSString *updateStatusURL = [NSString stringWithFormat:@"%@%@/", VoIPGRIDRequestOperationManagerURLTwoStepCall, callId];
    [self DELETE:updateStatusURL parameters:nil withCompletion:completion];
}

+ (NSString *)serviceName {
    return [[NSBundle mainBundle] bundleIdentifier];
}

#pragma mark - Notification handling

- (void)logoutUserNotification:(NSNotification *)notification {
    [self.operationQueue cancelAllOperations];
    [self.requestSerializer clearAuthorizationHeader];

    // Clear cookies for web view
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in cookieStorage.cookies) {
        [cookieStorage deleteCookie:cookie];
    }
}


@end
