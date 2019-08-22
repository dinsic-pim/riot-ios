/*
 Copyright 2014 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "LegacyAppDelegate.h"

#import <Intents/Intents.h>

#import "RoomDataSource.h"

#import "EventFormatter.h"

#import "RoomViewController.h"

#import "BugReportViewController.h"
#import "RoomKeyRequestViewController.h"

#import <MatrixKit/MatrixKit.h>

#import "Tools.h"
#import "WidgetManager.h"

#import "AFNetworkReachabilityManager.h"

#import <AudioToolbox/AudioToolbox.h>

#include <MatrixSDK/MXUIKitBackgroundModeHandler.h>

#import "WebViewViewController.h"

// Calls
#import "CallViewController.h"

#import "MXSession+Riot.h"
#import "MXRoom+Riot.h"

#import "GeneratedInterface-Swift.h"

//#define MX_CALL_STACK_OPENWEBRTC
#ifdef MX_CALL_STACK_OPENWEBRTC
#import <MatrixOpenWebRTCWrapper/MatrixOpenWebRTCWrapper.h>
#endif

#ifdef MX_CALL_STACK_ENDPOINT
#import <MatrixEndpointWrapper/MatrixEndpointWrapper.h>
#endif


#if __has_include(<MatrixSDK/MXJingleCallStack.h>)
// Tchap: Disable voip call for the moment
//#define CALL_STACK_JINGLE
#endif
#ifdef CALL_STACK_JINGLE
#import <MatrixSDK/MXJingleCallStack.h>
#endif

#define CALL_STATUS_BAR_HEIGHT 44

#define MAKE_STRING(x) #x
#define MAKE_NS_STRING(x) @MAKE_STRING(x)

NSString *const kAppDelegateDidTapStatusBarNotification = @"kAppDelegateDidTapStatusBarNotification";
NSString *const kAppDelegateNetworkStatusDidChangeNotification = @"kAppDelegateNetworkStatusDidChangeNotification";
NSString *const kLegacyAppDelegateDidLogoutNotification = @"kLegacyAppDelegateDidLogoutNotification";
NSString *const kLegacyAppDelegateDidLoginNotification = @"kLegacyAppDelegateDidLoginNotification";

@interface LegacyAppDelegate () <GDPRConsentViewControllerDelegate>
{
    /**
     Reachability observer
     */
    id reachabilityObserver;
    
    /**
     MatrixKit error observer
     */
    id matrixKitErrorObserver;
    
    /**
     matrix session observer used to detect new opened sessions.
     */
    id matrixSessionStateObserver;
    
    /**
     matrix account observers.
     */
    id addedAccountObserver;
    id removedAccountObserver;
    
    /**
     matrix call observer used to handle incoming/outgoing call.
     */
    id matrixCallObserver;
    
    /**
     The current call view controller (if any).
     */
    CallViewController *currentCallViewController;

    /**
     Incoming room key requests observers
     */
    id roomKeyRequestObserver;
    id roomKeyRequestCancellationObserver;

    /**
     If any the currently displayed sharing key dialog
     */
    RoomKeyRequestViewController *roomKeyRequestViewController;

    /**
     Account picker used in case of multiple account.
     */
    UIAlertController *accountPicker;
    
    /**
     Array of `MXSession` instances.
     */
    NSMutableArray *mxSessionArray;
    
    /**
     Suspend the error notifications when the navigation stack of the root view controller is updating.
     */
    BOOL isErrorNotificationSuspended;
    
    /**
     The listeners to call events.
     There is one listener per MXSession.
     The key is an identifier of the MXSession. The value, the listener.
     */
    NSMutableDictionary *callEventsListeners;
    
    /**
     The notification listener blocks.
     There is one block per MXSession.
     The key is an identifier of the MXSession. The value, the listener block.
     */
    NSMutableDictionary <NSNumber *, MXOnNotification> *notificationListenerBlocks;
    
    /**
     The list of the events which need to be notified at the end of the background sync.
     There is one list per MXSession.
     The key is an identifier of the MXSession. The value, an array of dictionaries (eventId, roomId... for each event).
     */
    NSMutableDictionary <NSNumber *, NSMutableArray <NSDictionary *> *> *eventsToNotify;

    /**
     Cache for payloads received with incoming push notifications.
     The key is the event id. The value, the payload.
     */
    NSMutableDictionary <NSString*, NSDictionary*> *incomingPushPayloads;

    /**
     Currently displayed "Call not supported" alert.
     */
    UIAlertController *noCallSupportAlert;
    
    /**
     Prompt to ask the user to log in again.
     */
    UIAlertController *cryptoDataCorruptedAlert;
    
    /**
     The launch screen container view
     */
    UIView *launchScreenContainerView;
    NSDate *launchAnimationStart;
}

@property (strong, nonatomic) UIAlertController *logoutConfirmation;

@property (weak, nonatomic) UIAlertController *gdprConsentNotGivenAlertController;
@property (weak, nonatomic) UIViewController *gdprConsentController;

/**
 Used to manage on boarding steps, like create DM with riot bot
 */
@property (strong, nonatomic) OnBoardingManager *onBoardingManager;

@property (nonatomic, nullable, copy) void (^registrationForRemoteNotificationsCompletion)(NSError *);


@property (nonatomic, strong) PKPushRegistry *pushRegistry;
@property (nonatomic) NSMutableDictionary <NSNumber *, NSMutableArray <NSString *> *> *incomingPushEventIds;

@end

@implementation LegacyAppDelegate

#pragma mark -

+ (void)initialize
{
    NSLog(@"[AppDelegate] initialize");
    
    [LegacyAppDelegate setupUserDefaults];

    // Set the App Group identifier.
    MXSDKOptions *sdkOptions = [MXSDKOptions sharedInstance];
    sdkOptions.applicationGroupIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:@"appGroupId"];

    // Redirect NSLogs to files only if we are not debugging
    if (!isatty(STDERR_FILENO))
    {
        [MXLogger redirectNSLogToFiles:YES];
    }

    NSLog(@"[AppDelegate] initialize: Done");
}

+ (instancetype)theDelegate
{
    static LegacyAppDelegate *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LegacyAppDelegate alloc] init];
    });
    
    return sharedInstance;
}

#pragma mark -

- (NSString*)appVersion
{
    if (!_appVersion)
    {
        _appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    }
    
    return _appVersion;
}

- (NSString*)build
{
    if (!_build)
    {
        NSString *buildBranch = nil;
        NSString *buildNumber = nil;
        // Check whether GIT_BRANCH and BUILD_NUMBER were provided during compilation in command line argument.
#ifdef GIT_BRANCH
        buildBranch = MAKE_NS_STRING(GIT_BRANCH);
#endif
#ifdef BUILD_NUMBER
        buildNumber = [NSString stringWithFormat:@"#%d", BUILD_NUMBER];
#endif
        if (buildBranch && buildNumber)
        {
            _build = [NSString stringWithFormat:@"%@ %@", buildBranch, buildNumber];
        } else if (buildNumber){
            _build = buildNumber;
        } else
        {
            _build = buildBranch ? buildBranch : @"";
        }
    }
    return _build;
}

- (void)setIsOffline:(BOOL)isOffline
{
    if (!reachabilityObserver)
    {
        // Define reachability observer when isOffline property is set for the first time
        reachabilityObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AFNetworkingReachabilityDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            
            NSNumber *statusItem = note.userInfo[AFNetworkingReachabilityNotificationStatusItem];
            if (statusItem)
            {
                AFNetworkReachabilityStatus reachabilityStatus = statusItem.integerValue;
                if (reachabilityStatus == AFNetworkReachabilityStatusNotReachable)
                {
                    [AppDelegate theDelegate].isOffline = YES;
                }
                else
                {
                    [AppDelegate theDelegate].isOffline = NO;
                }
            }
            
        }];
    }
    
    if (_isOffline != isOffline)
    {
        _isOffline = isOffline;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kAppDelegateNetworkStatusDidChangeNotification object:nil];
    }
}

- (UINavigationController*)secondaryNavigationController
{
    UIViewController* rootViewController = self.window.rootViewController;
    
    if ([rootViewController isKindOfClass:[UISplitViewController class]])
    {
        UISplitViewController *splitViewController = (UISplitViewController *)rootViewController;
        if (splitViewController.viewControllers.count == 2)
        {
            UIViewController *secondViewController = [splitViewController.viewControllers lastObject];
            
            if ([secondViewController isKindOfClass:[UINavigationController class]])
            {
                return (UINavigationController*)secondViewController;
            }
        }
    }
    
    return nil;
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions
{
    // Create message sound
    NSURL *messageSoundURL = [[NSBundle mainBundle] URLForResource:@"message" withExtension:@"mp3"];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)messageSoundURL, &_messageSound);
    
    // Prepare the launch screen displayed after the splash screen
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"LaunchScreen" bundle:[NSBundle mainBundle]];
    UIViewController *launchScreenVC = [storyboard instantiateViewControllerWithIdentifier:@"LaunchScreenId"];
    launchScreenContainerView = launchScreenVC.view;
    launchScreenContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    NSLog(@"[AppDelegate] willFinishLaunchingWithOptions: Done");

    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSDate *startDate = [NSDate date];
    
#ifdef DEBUG
    // log the full launchOptions only in DEBUG
    NSLog(@"[AppDelegate] didFinishLaunchingWithOptions: %@", launchOptions);
#else
    NSLog(@"[AppDelegate] didFinishLaunchingWithOptions");
#endif

    NSLog(@"[AppDelegate] didFinishLaunchingWithOptions: isProtectedDataAvailable: %@", @([application isProtectedDataAvailable]));

    // Log app information
    NSString *appDisplayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    NSString* appVersion = [AppDelegate theDelegate].appVersion;
    NSString* build = [AppDelegate theDelegate].build;
    
    NSLog(@"------------------------------");
    NSLog(@"Application info:");
    NSLog(@"%@ version: %@", appDisplayName, appVersion);
    NSLog(@"MatrixKit version: %@", MatrixKitVersion);
    NSLog(@"MatrixSDK version: %@", MatrixSDKVersion);
    NSLog(@"Build: %@\n", build);
    NSLog(@"------------------------------\n");

    // Set up runtime language and fallback by considering the userDefaults object shared within the application group.
    NSUserDefaults *sharedUserDefaults = [MXKAppSettings standardAppSettings].sharedUserDefaults;
    NSString *language = [sharedUserDefaults objectForKey:@"appLanguage"];
    if (!language)
    {
        // Check whether a langage was only defined at the Riot application level.
        language = [[NSUserDefaults standardUserDefaults] objectForKey:@"appLanguage"];
        if (language)
        {
            // Move this setting into the shared userDefaults object to apply it to the extensions.
            [sharedUserDefaults setObject:language forKey:@"appLanguage"];

            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"appLanguage"];
        }
    }
    [NSBundle mxk_setLanguage:language];
    [NSBundle mxk_setFallbackLanguage:@"fr"];
    
    // Customize the localized string table
    [NSBundle mxk_customizeLocalizedStringTableName:@"Vector"];
    
    mxSessionArray = [NSMutableArray array];
    callEventsListeners = [NSMutableDictionary dictionary];
    notificationListenerBlocks = [NSMutableDictionary dictionary];
    eventsToNotify = [NSMutableDictionary dictionary];
    incomingPushPayloads = [NSMutableDictionary dictionary];
    
    _isAppForeground = NO;
    
    // Tchap: Disable analytics use for the moment.
//    // Configure our analytics. It will indeed start if the option is enabled
//    [MXSDKOptions sharedInstance].analyticsDelegate = [Analytics sharedInstance];
//    [DecryptionFailureTracker sharedInstance].delegate = [Analytics sharedInstance];
//    [[Analytics sharedInstance] start];
    
    // Prepare Pushkit handling
    _incomingPushEventIds = [NSMutableDictionary dictionary];
    
    // Add matrix observers, and initialize matrix sessions if the app is not launched in background.
    [self initMatrixSessions];

    NSLog(@"[AppDelegate] didFinishLaunchingWithOptions: Done in %.0fms", [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationWillResignActive");
    
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    // Release MatrixKit error observer
    if (matrixKitErrorObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:matrixKitErrorObserver];
        matrixKitErrorObserver = nil;
    }
    
    if (self.errorNotification)
    {
        [self.errorNotification dismissViewControllerAnimated:NO completion:nil];
        self.errorNotification = nil;
    }
    
    if (accountPicker)
    {
        [accountPicker dismissViewControllerAnimated:NO completion:nil];
        accountPicker = nil;
    }
    
    if (noCallSupportAlert)
    {
        [noCallSupportAlert dismissViewControllerAnimated:NO completion:nil];
        noCallSupportAlert = nil;
    }
    
    if (cryptoDataCorruptedAlert)
    {
        [cryptoDataCorruptedAlert dismissViewControllerAnimated:NO completion:nil];
        cryptoDataCorruptedAlert = nil;
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationDidEnterBackground");
    
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    // Stop reachability monitoring
    if (reachabilityObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
        reachabilityObserver = nil;
    }
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:nil];
    [[AFNetworkReachabilityManager sharedManager] stopMonitoring];
    
    // check if some media must be released to reduce the cache size
    [MXMediaManager reduceCacheSizeToInsert:0];
    
    // Suspend all running matrix sessions
    NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
    for (MXKAccount *account in mxAccounts)
    {
        [account pauseInBackgroundTask];
    }
    
    // Refresh the notifications counter
    [self refreshApplicationIconBadgeNumber];
    
    _isAppForeground = NO;
    
    // Analytics: Force to send the pending actions
    [[DecryptionFailureTracker sharedInstance] dispatch];
    [[Analytics sharedInstance] dispatch];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationWillEnterForeground");
    
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    // Flush all the pending push notifications.
    for (NSMutableArray *array in self.incomingPushEventIds.allValues)
    {
        [array removeAllObjects];
    }
    [incomingPushPayloads removeAllObjects];
    
    // Force each session to refresh here their publicised groups by user dictionary.
    // When these publicised groups are retrieved for a user, they are cached and reused until the app is backgrounded and enters in the foreground again
    for (MXSession *session in mxSessionArray)
    {
        [session markOutdatedPublicisedGroupsByUserData];
    }
    
    _isAppForeground = YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationDidBecomeActive");
    
    // Check if there is crash log to send
    if (RiotSettings.shared.enableCrashReport)
    {
        [self checkExceptionToReport];
    }
    
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

    // Check if an initial sync failure occured while the app was in background
    MXSession *mainSession = self.mxSessions.firstObject;
    if (mainSession.state == MXSessionStateInitialSyncFailed)
    {
        // Inform the end user why the app appears blank
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                             code:NSURLErrorCannotConnectToHost
                                         userInfo:@{NSLocalizedDescriptionKey : NSLocalizedStringFromTable(@"homeserver_connection_lost", @"Vector", nil)}];

        [self showErrorAsAlert:error];
    }
    
    // Register to GDPR consent not given notification
    [self registerUserConsentNotGivenNotification];
    
    // Start monitoring reachability
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        
        // Check whether monitoring is ready
        if (status != AFNetworkReachabilityStatusUnknown)
        {
            if (status == AFNetworkReachabilityStatusNotReachable)
            {
                // Prompt user
                [[AppDelegate theDelegate] showErrorAsAlert:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:@{NSLocalizedDescriptionKey : NSLocalizedStringFromTable(@"network_offline_prompt", @"Vector", nil)}]];
            }
            else
            {
                self.isOffline = NO;
            }
            
            // Use a dispatch to avoid to kill ourselves
            dispatch_async(dispatch_get_main_queue(), ^{
                [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:nil];
            });
        }
        
    }];
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    
    // Observe matrixKit error to alert user on error
    matrixKitErrorObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKErrorNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        
        [self showErrorAsAlert:note.object];
        
    }];
    
    // Observe crypto data storage corruption
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSessionCryptoDidCorruptData:) name:kMXSessionCryptoDidCorruptDataNotification object:nil];
    
    // Resume all existing matrix sessions
    NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
    for (MXKAccount *account in mxAccounts)
    {
        [account resume];
    }
    
    // Refresh local contact from the contact book.
    [self refreshLocalContacts];
    
    _isAppForeground = YES;

    if (@available(iOS 11.0, *))
    {
        // Riot has its own dark theme. Prevent iOS from applying its one
        [application keyWindow].accessibilityIgnoresInvertColors = YES;
    }
    
    [self handleLaunchAnimation];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationWillTerminate");
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    NSLog(@"[AppDelegate] applicationDidReceiveMemoryWarning");
}

#pragma mark - Application layout handling

- (UIAlertController*)showErrorAsAlert:(NSError*)error
{
    // Ignore fake error, or connection cancellation error
    if (!error || ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled))
    {
        return nil;
    }
    
    // Ignore network reachability error when the app is already offline
    if (self.isOffline && [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorNotConnectedToInternet)
    {
        return nil;
    }
    
    if ([MXError isMXError:error])
    {
        MXError *mxError = [[MXError alloc] initWithNSError:error];
        // Ignore the listed error codes, and the "GDPR Consent not given" already caught by kMXHTTPClientUserConsentNotGivenErrorNotification,
        if ([mxError.errcode isEqualToString:kMXErrCodeStringConsentNotGiven]
            || [self.ignoredServerErrorCodes containsObject:mxError.errcode])
        {
            return nil;
        }
    }
    
    [_errorNotification dismissViewControllerAnimated:NO completion:nil];
    
    NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
    NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
    if (!title)
    {
        if (msg)
        {
            title = msg;
            msg = nil;
        }
        else
        {
            title = [NSBundle mxk_localizedStringForKey:@"error"];
        }
    }
    
    // Switch in offline mode in case of network reachability error
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorNotConnectedToInternet)
    {
        self.isOffline = YES;
    }
    
    return [self showAlertWithTitle:title message:msg];
}

- (UIAlertController*)showAlertWithTitle:(NSString*)title message:(NSString*)message
{
    [_errorNotification dismissViewControllerAnimated:NO completion:nil];
    
    _errorNotification = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [_errorNotification addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
                                                             
                                                             [AppDelegate theDelegate].errorNotification = nil;
                                                             
                                                         }]];
    // Display the error notification
    if (!isErrorNotificationSuspended)
    {
        [_errorNotification mxk_setAccessibilityIdentifier:@"AppDelegateErrorAlert"];
        [self showNotificationAlert:_errorNotification];
    }
    
    return self.errorNotification;
}

- (void)showNotificationAlert:(UIAlertController*)alert
{
    if (self.window.rootViewController.presentedViewController)
    {
        [alert popoverPresentationController].sourceView = self.window.rootViewController.presentedViewController.view;
        [alert popoverPresentationController].sourceRect = self.window.rootViewController.presentedViewController.view.bounds;
        [self.window.rootViewController.presentedViewController presentViewController:alert animated:YES completion:nil];
    }
    else
    {
        [alert popoverPresentationController].sourceView = self.window.rootViewController.view;
        [alert popoverPresentationController].sourceRect = self.window.rootViewController.view.bounds;
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

- (void)onSessionCryptoDidCorruptData:(NSNotification *)notification
{
    NSString *userId = notification.object;
    
    MXKAccount *account = [[MXKAccountManager sharedManager] accountForUserId:userId];
    if (account)
    {
        if (cryptoDataCorruptedAlert)
        {
            [cryptoDataCorruptedAlert dismissViewControllerAnimated:NO completion:nil];
        }
        
        cryptoDataCorruptedAlert = [UIAlertController alertControllerWithTitle:nil
                                                                       message:NSLocalizedStringFromTable(@"e2e_need_log_in_again", @"Vector", nil)
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        __weak typeof(self) weakSelf = self;
        
        [cryptoDataCorruptedAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"later"]
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * action) {
                                                                       
                                                                       if (weakSelf)
                                                                       {
                                                                           typeof(self) self = weakSelf;
                                                                           self->cryptoDataCorruptedAlert = nil;
                                                                       }
                                                                       
                                                                   }]];
        
        [cryptoDataCorruptedAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"settings_sign_out"]
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * action) {
                                                                       
                                                                       if (weakSelf)
                                                                       {
                                                                           typeof(self) self = weakSelf;
                                                                           self->cryptoDataCorruptedAlert = nil;
                                                                           
                                                                           [[MXKAccountManager sharedManager] removeAccount:account completion:nil];
                                                                       }
                                                                       
                                                                   }]];
        
        [self showNotificationAlert:cryptoDataCorruptedAlert];
    }
}

#pragma mark - Crash handling

// Check if there is a crash log to send to server
- (void)checkExceptionToReport
{
    // Check if the app crashed last time
    NSString *filePath = [MXLogger crashLog];
    if (filePath)
    {
        // Do not show the crash report dialog if it is already displayed
        if ([self.window.rootViewController.childViewControllers[0] isKindOfClass:[UINavigationController class]]
            && [((UINavigationController*)self.window.rootViewController.childViewControllers[0]).visibleViewController isKindOfClass:[BugReportViewController class]])
        {
            return;
        }
        
        NSString *description = [[NSString alloc] initWithContentsOfFile:filePath
                                                            usedEncoding:nil
                                                                   error:nil];
        
        NSLog(@"[AppDelegate] Promt user to report crash:\n%@", description);

        // Ask the user to send a crash report
        [[RageShakeManager sharedManager] promptCrashReportInViewController:self.window.rootViewController];
    }
}

#pragma mark - Push notifications

- (void)registerUserNotificationSettings
{
    if (!isPushRegistered)
    {
        NSMutableSet* notificationCategories = [NSMutableSet set];
        if ([[UIMutableUserNotificationAction class] instancesRespondToSelector:@selector(behavior)])
        {
            UIMutableUserNotificationAction* quickReply = [[UIMutableUserNotificationAction alloc] init];
            quickReply.title = NSLocalizedStringFromTable(@"room_message_short_placeholder", @"Vector", nil);
            quickReply.identifier = @"inline-reply";
            quickReply.activationMode = UIUserNotificationActivationModeBackground;
            quickReply.authenticationRequired = true;
            quickReply.behavior = UIUserNotificationActionBehaviorTextInput;

            UIMutableUserNotificationCategory* quickReplyCategory = [[UIMutableUserNotificationCategory alloc] init];
            quickReplyCategory.identifier = @"QUICK_REPLY";
            [quickReplyCategory setActions:[NSArray arrayWithObjects:quickReply, nil] forContext:UIUserNotificationActionContextDefault];
            [notificationCategories addObject:quickReplyCategory];
        }

        // Registration on iOS 8 and later
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge | UIUserNotificationTypeSound |UIUserNotificationTypeAlert) categories:notificationCategories];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
}

- (void)registerForRemoteNotificationsWithCompletion:(nullable void (^)(NSError *))completion
{
    self.registrationForRemoteNotificationsCompletion = completion;
    
    self.pushRegistry = [[PKPushRegistry alloc] initWithQueue:nil];
    self.pushRegistry.delegate = self;
    self.pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    // Register for remote notifications only if user provide access to notification feature
    if (notificationSettings.types != UIUserNotificationTypeNone)
    {
        [self registerForRemoteNotificationsWithCompletion:nil];
    }
    else
    {
        // Clear existing token
        MXKAccountManager* accountManager = [MXKAccountManager sharedManager];
        [accountManager setPushDeviceToken:nil withPushOptions:nil];
    }
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification withResponseInfo:(NSDictionary *)responseInfo completionHandler:(void (^)())completionHandler
{
    if ([identifier isEqualToString: @"inline-reply"])
    {
        NSString* roomId = notification.userInfo[@"room_id"];
        if (roomId.length)
        {
            NSArray* mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
            MXKRoomDataSource* roomDataSource = nil;
            MXKRoomDataSourceManager* manager;
            for (MXKAccount* account in mxAccounts)
            {
                MXRoom* room = [account.mxSession roomWithRoomId:roomId];
                if (room)
                {
                    manager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:account.mxSession];
                    if (manager)
                    {
                        break;
                    }
                }
            }
            if (manager == nil)
            {
                NSLog(@"[AppDelegate][Push] handleActionWithIdentifier: room with id %@ not found", roomId);
            }
            else
            {
                [manager roomDataSourceForRoom:roomId create:YES onComplete:^(MXKRoomDataSource *roomDataSource) {
                    NSString* responseText = [responseInfo objectForKey:UIUserNotificationActionResponseTypedTextKey];
                    if (responseText != nil && responseText.length != 0)
                    {
                        NSLog(@"[AppDelegate][Push] handleActionWithIdentifier: sending message to room: %@", roomId);
                        [roomDataSource sendTextMessage:responseText success:^(NSString* eventId) {} failure:^(NSError* error) {
                            UILocalNotification* failureNotification = [[UILocalNotification alloc] init];
                            failureNotification.alertBody = NSLocalizedStringFromTable(@"room_event_failed_to_send", @"Vector", nil);
                            failureNotification.userInfo = notification.userInfo;
                            [[UIApplication sharedApplication] scheduleLocalNotification: failureNotification];
                            NSLog(@"[AppDelegate][Push] handleActionWithIdentifier: error sending text message: %@", error);
                        }];
                    }

                    completionHandler();
                }];
                return;
            }
        }
    }
    else
    {
        NSLog(@"[AppDelegate][Push] handleActionWithIdentifier: unhandled identifier %@", identifier);
    }
    completionHandler();
}

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type
{
    NSData *token = credentials.token;
    
    NSUInteger len = ((token.length > 8) ? 8 : token.length / 2);
    NSLog(@"[AppDelegate][Push] Got Push token! (%@ ...)", [token subdataWithRange:NSMakeRange(0, len)]);
    
    MXKAccountManager* accountManager = [MXKAccountManager sharedManager];
    [accountManager setPushDeviceToken:token withPushOptions:@{@"format": @"event_id_only"}];
    
    isPushRegistered = YES;
    
    if (self.registrationForRemoteNotificationsCompletion)
    {
        self.registrationForRemoteNotificationsCompletion(nil);
        self.registrationForRemoteNotificationsCompletion = nil;
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type
{
    MXKAccountManager* accountManager = [MXKAccountManager sharedManager];
    [accountManager setPushDeviceToken:nil withPushOptions:nil];
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type
{
    NSLog(@"[AppDelegate][Push] didReceiveIncomingPushWithPayload: applicationState: %tu - type: %@ - payload: %@", [UIApplication sharedApplication].applicationState, payload.type, payload.dictionaryPayload);

    // Display local notifications only when the app is running in background.
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
    {
        NSLog(@"[AppDelegate][Push] didReceiveIncomingPushWithPayload while app is in background");
        
        // Check whether an event id is provided.
        NSString *eventId = payload.dictionaryPayload[@"event_id"];
        if (eventId)
        {
            // Add this event identifier in the pending push array for each session.
            for (NSMutableArray *array in self.incomingPushEventIds.allValues)
            {
                [array addObject:eventId];
            }

            // Cache payload for further usage
            incomingPushPayloads[eventId] = payload.dictionaryPayload;
        }
        else
        {
            NSLog(@"[AppDelegate][Push] didReceiveIncomingPushWithPayload - Unexpected payload %@", payload.dictionaryPayload);
        }
        
        // Trigger a background sync to handle notifications.
        [self launchBackgroundSync];
    }
}

- (void)launchBackgroundSync
{
    // Launch a background sync for all existing matrix sessions
    NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
    for (MXKAccount *account in mxAccounts)
    {
        // Check the current session state
        if (account.mxSession.state == MXSessionStatePaused)
        {
            NSLog(@"[AppDelegate][Push] launchBackgroundSync");
            __weak typeof(self) weakSelf = self;

            NSMutableArray<NSString *> *incomingPushEventIds = self.incomingPushEventIds[@(account.mxSession.hash)];
            NSMutableArray<NSString *> *incomingPushEventIdsCopy = [incomingPushEventIds copy];
            
            // Flush all the pending push notifications for this session.
            [incomingPushEventIds removeAllObjects];
            
            [account backgroundSync:20000 success:^{
                
                // Sanity check
                if (!weakSelf)
                {
                    return;
                }
                typeof(self) self = weakSelf;
                
                NSLog(@"[AppDelegate][Push] launchBackgroundSync: the background sync succeeds");
                
                // Trigger local notifcations
                [self handleLocalNotificationsForAccount:account];
                
                // Update app icon badge number
                [self refreshApplicationIconBadgeNumber];
                
            } failure:^(NSError *error) {
                
                NSLog(@"[AppDelegate][Push] launchBackgroundSync: the background sync failed. Error: %@ (%@). incomingPushEventIdsCopy: %@ - self.incomingPushEventIds: %@", error.domain, @(error.code), incomingPushEventIdsCopy, incomingPushEventIds);

                // Trigger limited local notifications when the sync with HS fails
                [self handleLimitedLocalNotifications:account.mxSession events:incomingPushEventIdsCopy];

                // Update app icon badge number
                [self refreshApplicationIconBadgeNumber];

            }];
        }
    }
}

- (void)handleLocalNotificationsForAccount:(MXKAccount*)account
{
    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: %@", account.mxCredentials.userId);
    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: eventsToNotify: %@", eventsToNotify[@(account.mxSession.hash)]);
    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: incomingPushEventIds: %@", self.incomingPushEventIds[@(account.mxSession.hash)]);

    __block NSUInteger scheduledNotifications = 0;

    // The call invite are handled here only when the callkit is not active.
    BOOL isCallKitActive = [MXCallKitAdapter callKitAvailable] && [MXKAppSettings standardAppSettings].isCallKitEnabled;
    
    NSMutableArray *eventsArray = eventsToNotify[@(account.mxSession.hash)];
    
    // Display a local notification for each event retrieved by the bg sync.
    for (NSUInteger index = 0; index < eventsArray.count; index++)
    {
        NSDictionary *eventDict = eventsArray[index];
        NSString *eventId = eventDict[@"event_id"];
        NSString *roomId = eventDict[@"room_id"];
        BOOL checkReadEvent = YES;
        MXEvent *event;

        // Ignore event already notified to the user
        if ([self displayedLocalNotificationForEvent:eventId andUser:account.mxCredentials.userId type:nil])
        {
            NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: Skip event already displayed in a notification. Event id: %@", eventId);
            continue;
        }
        
        if (eventId && roomId)
        {
            event = [account.mxSession.store eventWithEventId:eventId inRoom:roomId];
        }
        
        if (event)
        {
            // Ignore redacted event.
            if (event.isRedactedEvent)
            {
                NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: Skip redacted event. Event id: %@", event.eventId);
                continue;
            }
            
            // Consider here the call invites
            if (event.eventType == MXEventTypeCallInvite)
            {
                // Ignore call invite when callkit is active.
                if (isCallKitActive)
                {
                    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: Skip call event. Event id: %@", event.eventId);
                    continue;
                }
                else
                {
                    // Retrieve the current call state from the call manager
                    MXCallInviteEventContent *callInviteEventContent = [MXCallInviteEventContent modelFromJSON:event.content];
                    MXCall *call = [account.mxSession.callManager callWithCallId:callInviteEventContent.callId];
                    
                    if (call.state <= MXCallStateRinging)
                    {
                        // Keep display a local notification even if the event has been read on another device.
                        checkReadEvent = NO;
                    }
                }
            }
            
            if (checkReadEvent)
            {
                // Ignore event which has been read on another device.
                MXReceiptData *readReceipt = [account.mxSession.store getReceiptInRoom:roomId forUserId:account.mxCredentials.userId];
                if (readReceipt)
                {
                    MXEvent *readReceiptEvent = [account.mxSession.store eventWithEventId:readReceipt.eventId inRoom:roomId];
                    if (event.originServerTs <= readReceiptEvent.originServerTs)
                    {
                        NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: Skip already read event. Event id: %@", event.eventId);
                        continue;
                    }
                }
            }
            
            // Prepare the local notification
            MXPushRule *rule = eventDict[@"push_rule"];

            [self notificationBodyForEvent:event pushRule:rule inAccount:account onComplete:^(NSString * _Nullable notificationBody) {

                if (notificationBody)
                {
                    // Printf style escape characters are stripped from the string prior to display;
                    // to include a percent symbol (%) in the message, use two percent symbols (%%).
                    notificationBody = [notificationBody stringByReplacingOccurrencesOfString:@"%" withString:@"%%"];

                    UILocalNotification *eventNotification = [[UILocalNotification alloc] init];
                    eventNotification.alertBody = notificationBody;
                    eventNotification.userInfo = @{
                                                   @"type": @"full",
                                                   @"room_id": event.roomId,
                                                   @"event_id": event.eventId,
                                                   @"user_id": account.mxCredentials.userId
                                                   };

                    BOOL isNotificationContentShown = !event.isEncrypted || RiotSettings.shared.showDecryptedContentInNotifications;

                    if ((event.eventType == MXEventTypeRoomMessage || event.eventType == MXEventTypeRoomEncrypted) && isNotificationContentShown)
                    {
                        eventNotification.category = @"QUICK_REPLY";
                    }

                    // Set sound name based on the value provided in action of MXPushRule
                    for (MXPushRuleAction *action in rule.actions)
                    {
                        if (action.actionType == MXPushRuleActionTypeSetTweak)
                        {
                            if ([action.parameters[@"set_tweak"] isEqualToString:@"sound"])
                            {
                                NSString *soundName = action.parameters[@"value"];
                                if ([soundName isEqualToString:@"default"])
                                    soundName = @"message.mp3";

                                eventNotification.soundName = soundName;
                            }
                        }
                    }

                    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: Display notification for event %@", event.eventId);
                    [[UIApplication sharedApplication] scheduleLocalNotification:eventNotification];
                    scheduledNotifications++;
                }
                else
                {
                    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: Skip event with empty generated notificationBody. Event id: %@", event.eventId);
                }
            }];
        }
    }

    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: Sent %tu local notifications for %tu events", scheduledNotifications, eventsArray.count);

    [eventsArray removeAllObjects];
}

- (void)notificationBodyForEvent:(MXEvent *)event pushRule:(MXPushRule*)rule inAccount:(MXKAccount*)account onComplete:(void (^)(NSString * _Nullable notificationBody))onComplete;
{
    if (!event.content || !event.content.count)
    {
        NSLog(@"[AppDelegate][Push] notificationBodyForEvent: empty event content");
        onComplete (nil);
        return;
    }
    
    MXRoom *room = [account.mxSession roomWithRoomId:event.roomId];
    if (!room)
    {
        NSLog(@"[AppDelegate][Push] notificationBodyForEvent: Unknown room");
        onComplete (nil);
        return;
    }

    [room state:^(MXRoomState *roomState) {

        NSString *notificationBody;
        NSString *eventSenderName = [roomState.members memberName:event.sender];

        if (event.eventType == MXEventTypeRoomMessage || event.eventType == MXEventTypeRoomEncrypted)
        {
            if (room.isMentionsOnly)
            {
                // A local notification will be displayed only for highlighted notification.
                BOOL isHighlighted = NO;

                // Check whether is there an highlight tweak on it
                for (MXPushRuleAction *ruleAction in rule.actions)
                {
                    if (ruleAction.actionType == MXPushRuleActionTypeSetTweak)
                    {
                        if ([ruleAction.parameters[@"set_tweak"] isEqualToString:@"highlight"])
                        {
                            // Check the highlight tweak "value"
                            // If not present, highlight. Else check its value before highlighting
                            if (nil == ruleAction.parameters[@"value"] || YES == [ruleAction.parameters[@"value"] boolValue])
                            {
                                isHighlighted = YES;
                                break;
                            }
                        }
                    }
                }

                if (!isHighlighted)
                {
                    // Ignore this notif.
                    NSLog(@"[AppDelegate][Push] notificationBodyForEvent: Ignore non highlighted notif in mentions only room");
                    onComplete(nil);
                    return;
                }
            }

            NSString *msgType = event.content[@"msgtype"];
            NSString *content = event.content[@"body"];

            if (event.isEncrypted && !RiotSettings.shared.showDecryptedContentInNotifications)
            {
                // Hide the content
                msgType = nil;
            }

            NSString *roomDisplayName = room.summary.displayname;

            // Display the room name only if it is different than the sender name
            if (roomDisplayName.length && ![roomDisplayName isEqualToString:eventSenderName])
            {
                if ([msgType isEqualToString:@"m.text"])
                    notificationBody = [NSString stringWithFormat:NSLocalizedString(@"MSG_FROM_USER_IN_ROOM_WITH_CONTENT", nil), eventSenderName,roomDisplayName, content];
                else if ([msgType isEqualToString:@"m.emote"])
                    notificationBody = [NSString stringWithFormat:NSLocalizedString(@"ACTION_FROM_USER_IN_ROOM", nil), roomDisplayName, eventSenderName, content];
                else if ([msgType isEqualToString:@"m.image"])
                    notificationBody = [NSString stringWithFormat:NSLocalizedString(@"IMAGE_FROM_USER_IN_ROOM", nil), eventSenderName, content, roomDisplayName];
                else
                    // Encrypted messages falls here
                    notificationBody = [NSString stringWithFormat:NSLocalizedString(@"MSG_FROM_USER_IN_ROOM", nil), eventSenderName, roomDisplayName];
            }
            else
            {
                if ([msgType isEqualToString:@"m.text"])
                    notificationBody = [NSString stringWithFormat:NSLocalizedString(@"MSG_FROM_USER_WITH_CONTENT", nil), eventSenderName, content];
                else if ([msgType isEqualToString:@"m.emote"])
                    notificationBody = [NSString stringWithFormat:NSLocalizedString(@"ACTION_FROM_USER", nil), eventSenderName, content];
                else if ([msgType isEqualToString:@"m.image"])
                    notificationBody = [NSString stringWithFormat:NSLocalizedString(@"IMAGE_FROM_USER", nil), eventSenderName, content];
                else
                    // Encrypted messages falls here
                    notificationBody = [NSString stringWithFormat:NSLocalizedString(@"MSG_FROM_USER", nil), eventSenderName];
            }
        }
        else if (event.eventType == MXEventTypeCallInvite)
        {
            NSString *sdp = event.content[@"offer"][@"sdp"];
            BOOL isVideoCall = [sdp rangeOfString:@"m=video"].location != NSNotFound;

            if (!isVideoCall)
                notificationBody = [NSString stringWithFormat:NSLocalizedString(@"VOICE_CALL_FROM_USER", nil), eventSenderName];
            else
                notificationBody = [NSString stringWithFormat:NSLocalizedString(@"VIDEO_CALL_FROM_USER", nil), eventSenderName];
        }
        else if (event.eventType == MXEventTypeRoomMember)
        {
            NSString *roomDisplayName = room.summary.displayname;

            if (roomDisplayName.length && ![roomDisplayName isEqualToString:eventSenderName])
                notificationBody = [NSString stringWithFormat:NSLocalizedString(@"USER_INVITE_TO_NAMED_ROOM", nil), eventSenderName, roomDisplayName];
            else
                notificationBody = [NSString stringWithFormat:NSLocalizedString(@"USER_INVITE_TO_CHAT", nil), eventSenderName];
        }
        else if (event.eventType == MXEventTypeSticker)
        {
            NSString *roomDisplayName = room.summary.displayname;

            if (roomDisplayName.length && ![roomDisplayName isEqualToString:eventSenderName])
                notificationBody = [NSString stringWithFormat:NSLocalizedString(@"MSG_FROM_USER_IN_ROOM", nil), eventSenderName, roomDisplayName];
            else
                notificationBody = [NSString stringWithFormat:NSLocalizedString(@"MSG_FROM_USER", nil), eventSenderName];
        }

        onComplete(notificationBody);
    }];
}

/**
 Display "limited" notifications for events the app was not able to get data
 (because of /sync failure).

 In this situation, we are only able to display "You received a message in %@".

 @param mxSession the matrix session where the /sync failed.
 @param events the list of events id we did not get data.
 */
- (void)handleLimitedLocalNotifications:(MXSession*)mxSession events:(NSArray<NSString *> *)events
{
    NSString *userId = mxSession.matrixRestClient.credentials.userId;

    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForFailedSync: %@", userId);
    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForFailedSync: eventsToNotify: %@", eventsToNotify[@(mxSession.hash)]);
    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForFailedSync: incomingPushEventIds: %@", self.incomingPushEventIds[@(mxSession.hash)]);
    NSLog(@"[AppDelegate][Push] handleLocalNotificationsForFailedSync: events: %@", events);

    if (!events.count)
    {
        return;
    }

    for (NSString *eventId in events)
    {
        // Ignore event already notified to the user
        if ([self displayedLocalNotificationForEvent:eventId andUser:userId type:nil])
        {
            NSLog(@"[AppDelegate][Push] handleLocalNotificationsForAccount: Skip event already displayed in a notification. Event id: %@", eventId);
            continue;
        }

        // Build notification user info
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                        @"type": @"limited",
                                                                                        @"event_id": eventId,
                                                                                        @"user_id": userId
                                                                                        }];

        // Add the room_id so that user will open the room when tapping on the notif
        NSDictionary *payload = incomingPushPayloads[eventId];
        NSString *roomId = payload[@"room_id"];
        if (roomId)
        {
            userInfo[@"room_id"] = roomId;
        }
        else
        {
            NSLog(@"[AppDelegate][Push] handleLocalNotificationsForFailedSync: room_id is missing for event %@ in payload %@", eventId, payload);
        }

        UILocalNotification *localNotificationForFailedSync =  [[UILocalNotification alloc] init];
        localNotificationForFailedSync.userInfo = userInfo;
        localNotificationForFailedSync.alertBody = [self limitedNotificationBodyForEvent:eventId inMatrixSession:mxSession];

        NSLog(@"[AppDelegate][Push] handleLocalNotificationsForFailedSync: Display notification for event %@", eventId);
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotificationForFailedSync];
    }
}

/**
 Build the body for the "limited" notification to display to the user.

 @param eventId the id of the event the app failed to get data.
 @param mxSession the matrix session where the /sync failed.
 @return the string to display in the local notification.
 */
- (nullable NSString *)limitedNotificationBodyForEvent:(NSString *)eventId inMatrixSession:(MXSession*)mxSession
{
    NSString *notificationBody;

    NSString *roomDisplayName;

    NSDictionary *payload = incomingPushPayloads[eventId];
    NSString *roomId = payload[@"room_id"];
    if (roomId)
    {
        MXRoomSummary *roomSummary = [mxSession roomSummaryWithRoomId:roomId];
        if (roomSummary)
        {
            roomDisplayName = roomSummary.displayname;
        }
    }

    if (roomDisplayName.length)
    {
        notificationBody = [NSString stringWithFormat:NSLocalizedString(@"SINGLE_UNREAD_IN_ROOM", nil), roomDisplayName];
    }
    else
    {
        notificationBody = NSLocalizedString(@"SINGLE_UNREAD", nil);
    }

    return notificationBody;
}

/**
 Return the already displayed notification for an event.

 @param eventId the id of the event attached to the notification to find.
 @param userId the id of the user attached to the notification to find.
 @param type the type of notification. @"full" or @"limited". nil for any type.
 @return the local notification if any.
 */
// TODO: This method does not work: [[UIApplication sharedApplication] scheduledLocalNotifications] is not reliable
- (UILocalNotification*)displayedLocalNotificationForEvent:(NSString*)eventId andUser:(NSString*)userId type:(NSString*)type
{
    NSLog(@"[AppDelegate] displayedLocalNotificationForEvent: %@ andUser: %@. Current scheduledLocalNotifications: %@", eventId, userId, [[UIApplication sharedApplication] scheduledLocalNotifications]);

    UILocalNotification *limitedLocalNotification;
    for (UILocalNotification *localNotification in [[UIApplication sharedApplication] scheduledLocalNotifications])
    {
        NSLog(@"    - %@", localNotification.userInfo);

        if ([localNotification.userInfo[@"event_id"] isEqualToString:eventId]
            && [localNotification.userInfo[@"user_id"] isEqualToString:userId]
            && (!type || [localNotification.userInfo[@"type"] isEqualToString:type]))
        {
            limitedLocalNotification = localNotification;
            break;
        }
    }

    NSLog(@"[AppDelegate] displayedLocalNotificationForEvent: found: %@", limitedLocalNotification);

    return limitedLocalNotification;
}

- (void)refreshApplicationIconBadgeNumber
{
    // Consider the total number of missed discussions including the invites.
    NSUInteger count = [self missedDiscussionsCount];
    
    NSLog(@"[AppDelegate] refreshApplicationIconBadgeNumber: %tu", count);
    
    [UIApplication sharedApplication].applicationIconBadgeNumber = count;
}

- (NSUInteger)missedDiscussionsCount
{
    NSUInteger roomCount = 0;
    
    // Considering all the current sessions.
    for (MXSession *session in mxSessionArray)
    {
        roomCount += [session riot_missedDiscussionsCount];
    }
    
    return roomCount;
}

#pragma mark - Matrix sessions handling

- (void)initMatrixSessions
{
    NSLog(@"[AppDelegate] initMatrixSessions");
    
    MXSDKOptions *sdkOptions = [MXSDKOptions sharedInstance];
    
    // Define the media cache version
    sdkOptions.mediaCacheAppVersion = 0;
    
    // Enable e2e encryption for newly created MXSession
    sdkOptions.enableCryptoWhenStartingMXSession = YES;
    
    // Disable identicon use
    sdkOptions.disableIdenticonUseForUserAvatar = YES;
    
    // Use UIKit BackgroundTask for handling background tasks in the SDK
    sdkOptions.backgroundModeHandler = [[MXUIKitBackgroundModeHandler alloc] init];

    // Get modular widget events in rooms histories
    [[MXKAppSettings standardAppSettings] addSupportedEventTypes:@[kWidgetMatrixEventTypeString, kWidgetModularEventTypeString]];
    
    // Tchap: remove some state events from the rooms histories: the history access, encryption
    [[MXKAppSettings standardAppSettings] removeSupportedEventTypes:@[kMXEventTypeStringRoomHistoryVisibility, kMXEventTypeStringRoomEncryption]];
    
    // Disable long press on event in bubble cells
    [MXKRoomBubbleTableViewCell disableLongPressGestureOnEvent:YES];
    
    // Set first RoomDataSource class used in Vector
    [MXKRoomDataSourceManager registerRoomDataSourceClass:RoomDataSource.class];
    
    // Register matrix session state observer in order to handle multi-sessions.
    matrixSessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        MXSession *mxSession = (MXSession*)notif.object;
        
        // Check whether the concerned session is a new one
        if (mxSession.state == MXSessionStateInitialised)
        {
            // Store this new session
            [self addMatrixSession:mxSession];
            
            // Set the VoIP call stack (if supported).
            id<MXCallStack> callStack;
            
#ifdef MX_CALL_STACK_OPENWEBRTC
            callStack = [[MXOpenWebRTCCallStack alloc] init];
#endif
#ifdef MX_CALL_STACK_ENDPOINT
            callStack = [[MXEndpointCallStack alloc] initWithMatrixId:mxSession.myUser.userId];
#endif
#ifdef CALL_STACK_JINGLE
            callStack = [[MXJingleCallStack alloc] init];
#endif
            if (callStack)
            {
                [mxSession enableVoIPWithCallStack:callStack];

                // Let's call invite be valid for 1 minute
                mxSession.callManager.inviteLifetime = 60000;

                // Setup CallKit
                if ([MXCallKitAdapter callKitAvailable])
                {
                    BOOL isCallKitEnabled = [MXKAppSettings standardAppSettings].isCallKitEnabled;
                    [self enableCallKit:isCallKitEnabled forCallManager:mxSession.callManager];
                    
                    // Register for changes performed by the user
                    [[MXKAppSettings standardAppSettings] addObserver:self
                                                           forKeyPath:@"enableCallKit"
                                                              options:NSKeyValueObservingOptionNew
                                                              context:NULL];
                }
            }
            else
            {
                // When there is no call stack, display alerts on call invites
                [self enableNoVoIPOnMatrixSession:mxSession];
            }
            
            // Each room member will be considered as a potential contact.
            [MXKContactManager sharedManager].contactManagerMXRoomSource = MXKContactManagerMXRoomSourceAll;

            // Send read receipts for widgets events too
            NSMutableArray<MXEventTypeString> *acknowledgableEventTypes = [NSMutableArray arrayWithArray:mxSession.acknowledgableEventTypes];
            [acknowledgableEventTypes addObject:kWidgetMatrixEventTypeString];
            [acknowledgableEventTypes addObject:kWidgetModularEventTypeString];
            mxSession.acknowledgableEventTypes = acknowledgableEventTypes;
        }
        else if (mxSession.state == MXSessionStateStoreDataReady)
        {
            // A new call observer may be added here
            [self addMatrixCallObserver];
            
            // Enable local notifications
            [self enableLocalNotificationsFromMatrixSession:mxSession];
        }
        else if (mxSession.state == MXSessionStateClosed)
        {
            [self removeMatrixSession:mxSession];
        }
        // Consider here the case where the app is running in background.
        else if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
        {
            NSLog(@"[AppDelegate][Push] MXSession state changed while in background. mxSession.state: %tu - incomingPushEventIds: %@", mxSession.state, self.incomingPushEventIds[@(mxSession.hash)]);
            if (mxSession.state == MXSessionStateRunning)
            {
                // Pause the session in background task
                NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
                for (MXKAccount *account in mxAccounts)
                {
                    if (account.mxSession == mxSession)
                    {
                        [account pauseInBackgroundTask];
                        
                        // Trigger local notifcations (Indeed the app finishs here an initial sync in background, the user has missed some notifcations)
                        [self handleLocalNotificationsForAccount:account];
                        
                        // Update app icon badge number
                        [self refreshApplicationIconBadgeNumber];
                        
                        break;
                    }
                }
            }
            else if (mxSession.state == MXSessionStatePaused)
            {
                // Check whether some push notifications are pending for this session.
                if (self.incomingPushEventIds[@(mxSession.hash)].count)
                {
                    NSLog(@"[AppDelegate][Push] relaunch a background sync for %tu kMXSessionStateDidChangeNotification pending incoming pushes", self.incomingPushEventIds[@(mxSession.hash)].count);
                    [self launchBackgroundSync];
                }
            }
            else if (mxSession.state == MXSessionStateInitialSyncFailed)
            {
                // Display failure sync notifications for pending events if any
                if (self.incomingPushEventIds[@(mxSession.hash)].count)
                {
                    NSLog(@"[AppDelegate][Push] initial sync failed with %tu pending incoming pushes", self.incomingPushEventIds[@(mxSession.hash)].count);

                    // Trigger limited local notifications when the sync with HS fails
                    [self handleLimitedLocalNotifications:mxSession events:self.incomingPushEventIds[@(mxSession.hash)]];

                    // Update app icon badge number
                    [self refreshApplicationIconBadgeNumber];
                }
             }
        }
        else if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
        {
            if (mxSession.state == MXSessionStateRunning)
            {
                // Check if we need to display a key share dialog
                [self checkPendingRoomKeyRequests];
            }
        }
        
        [self handleLaunchAnimation];
    }];
    
    // Register an observer in order to handle new account
    addedAccountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountManagerDidAddAccountNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        // Finalize the initialization of this new account
        MXKAccount *account = notif.object;
        if (account)
        {
            // Replace default room summary updater
            EventFormatter *eventFormatter = [[EventFormatter alloc] initWithMatrixSession:account.mxSession];
            eventFormatter.isForSubtitle = YES;
            account.mxSession.roomSummaryUpdateDelegate = eventFormatter;
            
            // Set the push gateway URL.
            account.pushGatewayURL = [[NSUserDefaults standardUserDefaults] objectForKey:@"pushGatewayURL"];
            
            if (isPushRegistered)
            {
                // Enable push notifications by default on new added account
                [account enablePushKitNotifications:YES success:nil failure:nil];
            }
            else
            {
                // Set up push notifications
                [self registerUserNotificationSettings];
            }
        }
        
        // Load the local contacts on first account creation.
        if ([MXKAccountManager sharedManager].accounts.count == 1)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self refreshLocalContacts];
                
            });
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kLegacyAppDelegateDidLoginNotification object:nil];
        }
    }];
    
    // Add observer to handle removed accounts
    removedAccountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountManagerDidRemoveAccountNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        // Clear Modular data
        MXKAccount *account = notif.object;
        [[WidgetManager sharedManager] deleteDataForUser:account.mxCredentials.userId];
        
        // Logout the app when there is no available account
        if (![MXKAccountManager sharedManager].accounts.count)
        {
            [self logoutWithConfirmation:NO completion:nil];
        }
    }];
    
    // Prepare account manager
    MXKAccountManager *accountManager = [MXKAccountManager sharedManager];
    
    // Use MXFileStore as MXStore to permanently store events.
    accountManager.storeClass = [MXFileStore class];
    
    // Disable APNS use.
    if (accountManager.apnsDeviceToken)
    {
        // We use now Pushkit, unregister for all remote notifications received via Apple Push Notification service.
        [[UIApplication sharedApplication] unregisterForRemoteNotifications];
        [accountManager setApnsDeviceToken:nil];
    }
    
    // Observers have been defined, we can start a matrix session for each enabled accounts.
    NSLog(@"[AppDelegate] initMatrixSessions: prepareSessionForActiveAccounts (app state: %tu)", [[UIApplication sharedApplication] applicationState]);
    [accountManager prepareSessionForActiveAccounts];
    
    // Check whether we're already logged in
    NSArray *mxAccounts = accountManager.activeAccounts;
    if (mxAccounts.count)
    {
        for (MXKAccount *account in mxAccounts)
        {
            // Replace default room summary updater
            EventFormatter *eventFormatter = [[EventFormatter alloc] initWithMatrixSession:account.mxSession];
            eventFormatter.isForSubtitle = YES;
            account.mxSession.roomSummaryUpdateDelegate = eventFormatter;
            
            // The push gateway url is now configurable.
            // Set this url in the existing accounts when it is undefined.
            if (!account.pushGatewayURL)
            {
                account.pushGatewayURL = [[NSUserDefaults standardUserDefaults] objectForKey:@"pushGatewayURL"];
            }
        }
        
        // Set up push notifications
        [self registerUserNotificationSettings];
    }
}

- (NSArray*)mxSessions
{
    return [NSArray arrayWithArray:mxSessionArray];
}

- (void)addMatrixSession:(MXSession *)mxSession
{
    if (mxSession)
    {
        // Report this session to contact manager
        // But wait a bit that our launch animation screen is ready to show and
        // displayed if needed. As the processing in MXKContactManager can lock
        // the UI thread for several seconds, it is better to show the animation
        // during this blocking task.
        dispatch_after(dispatch_walltime(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [[MXKContactManager sharedManager] addMatrixSession:mxSession];
        });

        // Register the session to the widgets manager
        [[WidgetManager sharedManager] addMatrixSession:mxSession];
        
        [mxSessionArray addObject:mxSession];
        
        // Do the one time check on device id
        [self checkDeviceId:mxSession];
        
        // Add an array to handle incoming push
        self.incomingPushEventIds[@(mxSession.hash)] = [NSMutableArray array];

        // Enable listening of incoming key share requests
        [self enableRoomKeyRequestObserver:mxSession];
    }
}

- (void)removeMatrixSession:(MXSession*)mxSession
{
    [[MXKContactManager sharedManager] removeMatrixSession:mxSession];

    // Update the widgets manager
    [[WidgetManager sharedManager] removeMatrixSession:mxSession]; 
    
    // If any, disable the no VoIP support workaround
    [self disableNoVoIPOnMatrixSession:mxSession];
    
    // Disable local notifications from this session
    [self disableLocalNotificationsFromMatrixSession:mxSession];

    // Disable listening of incoming key share requests
    [self disableRoomKeyRequestObserver:mxSession];
    
    [mxSessionArray removeObject:mxSession];
    
    if (!mxSessionArray.count && matrixCallObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:matrixCallObserver];
        matrixCallObserver = nil;
    }
    
    [self.incomingPushEventIds removeObjectForKey:@(mxSession.hash)];
}

- (void)markAllMessagesAsRead
{
    for (MXSession *session in mxSessionArray)
    {
        [session markAllMessagesAsRead];
    }
}

- (void)logoutWithConfirmation:(BOOL)askConfirmation completion:(void (^)(BOOL isLoggedOut))completion
{
    // Check whether we have to ask confirmation before logging out.
    if (askConfirmation)
    {
        if (self.logoutConfirmation)
        {
            [self.logoutConfirmation dismissViewControllerAnimated:NO completion:nil];
            self.logoutConfirmation = nil;
        }
        
        __weak typeof(self) weakSelf = self;
        
        NSString *message = NSLocalizedStringFromTable(@"settings_sign_out_confirmation", @"Vector", nil);
        
        // If the user has encrypted rooms, warn he will lose his e2e keys
        MXSession *session = self.mxSessions.firstObject;
        for (MXRoom *room in session.rooms)
        {
            if (room.summary.isEncrypted)
            {
                message = [message stringByAppendingString:[NSString stringWithFormat:@"\n\n%@", NSLocalizedStringFromTable(@"settings_sign_out_e2e_warn", @"Vector", nil)]];
                break;
            }
        }
        
        // Ask confirmation
        self.logoutConfirmation = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"settings_sign_out", @"Vector", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [self.logoutConfirmation addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"settings_sign_out", @"Vector", nil)
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               self.logoutConfirmation = nil;
                                                               
                                                               dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                                                   
                                                                   [self logoutWithConfirmation:NO completion:completion];
                                                                   
                                                               });
                                                           }
                                                           
                                                       }]];
        
        [self.logoutConfirmation addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               self.logoutConfirmation = nil;
                                                               
                                                               if (completion)
                                                               {
                                                                   completion(NO);
                                                               }
                                                           }
                                                           
                                                       }]];
        
        [self.logoutConfirmation mxk_setAccessibilityIdentifier: @"AppDelegateLogoutConfirmationAlert"];
        [self showNotificationAlert:self.logoutConfirmation];
        return;
    }
    
    [self logoutSendingRequestServer:YES completion:^(BOOL isLoggedOut) {
        if (completion)
        {
            completion (YES);
        }
        
        if (isLoggedOut)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kLegacyAppDelegateDidLogoutNotification object:nil];
        }
    }];
}

- (void)logoutSendingRequestServer:(BOOL)sendLogoutServerRequest
                        completion:(void (^)(BOOL isLoggedOut))completion
{
    self.pushRegistry = nil;
    isPushRegistered = NO;
    
    // Clear cache
    [MXMediaManager clearCache];
    
#ifdef MX_CALL_STACK_ENDPOINT
    // Erase all created certificates and private keys by MXEndpointCallStack
    for (MXKAccount *account in MXKAccountManager.sharedManager.accounts)
    {
        if ([account.mxSession.callManager.callStack isKindOfClass:MXEndpointCallStack.class])
        {
            [(MXEndpointCallStack*)account.mxSession.callManager.callStack deleteData:account.mxSession.myUser.userId];
        }
    }
#endif
    
    // Logout all matrix account
    [[MXKAccountManager sharedManager] logoutWithCompletion:^{
        
        if (completion)
        {
            completion (YES);
        }
        
        // Note: Keep App settings
        // But enforce usage of member lazy loading
        [MXKAppSettings standardAppSettings].syncWithLazyLoadOfRoomMembers = YES;
        
        // Reset the contact manager
        [[MXKContactManager sharedManager] reset];
        
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == [MXKAppSettings standardAppSettings] && [keyPath isEqualToString:@"enableCallKit"])
    {
        BOOL isCallKitEnabled = [MXKAppSettings standardAppSettings].isCallKitEnabled;
        MXCallManager *callManager = [[[[[MXKAccountManager sharedManager] activeAccounts] firstObject] mxSession] callManager];
        [self enableCallKit:isCallKitEnabled forCallManager:callManager];
    }
}

- (void)addMatrixCallObserver
{
    if (matrixCallObserver)
    {
        return;
    }
    
    // Register call observer in order to handle incoming calls
    matrixCallObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXCallManagerNewCall
                                                                           object:nil
                                                                            queue:[NSOperationQueue mainQueue]
                                                                       usingBlock:^(NSNotification *notif)
    {
        // Ignore the call if a call is already in progress
        if (!currentCallViewController && !_jitsiViewController)
        {
            MXCall *mxCall = (MXCall*)notif.object;
            
            BOOL isCallKitEnabled = [MXCallKitAdapter callKitAvailable] && [MXKAppSettings standardAppSettings].isCallKitEnabled;
            
            // Prepare the call view controller
            currentCallViewController = [CallViewController callViewController:nil];
            currentCallViewController.playRingtone = !isCallKitEnabled;
            currentCallViewController.mxCall = mxCall;
            currentCallViewController.delegate = self;

            UIApplicationState applicationState = UIApplication.sharedApplication.applicationState;
            
            // App has been woken by PushKit notification in the background
            if (applicationState == UIApplicationStateBackground && mxCall.isIncoming)
            {
                // Create backgound task.
                // Without CallKit this will allow us to play vibro until the call was ended
                // With CallKit we'll inform the system when the call is ended to let the system terminate our app to save resources
                id<MXBackgroundModeHandler> handler = [MXSDKOptions sharedInstance].backgroundModeHandler;
                NSUInteger callTaskIdentifier = [handler startBackgroundTaskWithName:nil completion:^{}];
                
                // Start listening for call state change notifications
                __weak NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
                __block id token = [[NSNotificationCenter defaultCenter] addObserverForName:kMXCallStateDidChange
                                                                                     object:mxCall
                                                                                      queue:nil
                                                                                 usingBlock:^(NSNotification * _Nonnull note) {
                                                                                     MXCall *call = (MXCall *)note.object;
                                                                                     
                                                                                     if (call.state == MXCallStateEnded)
                                                                                     {
                                                                                         // Set call vc to nil to let our app handle new incoming calls even it wasn't killed by the system
                                                                                         currentCallViewController = nil;
                                                                                         [notificationCenter removeObserver:token];
                                                                                         
                                                                                         [handler endBackgrounTaskWithIdentifier:callTaskIdentifier];
                                                                                     }
                                                                                 }];
            }

            if (mxCall.isIncoming && isCallKitEnabled)
            {
                // Let's CallKit display the system incoming call screen
                // Show the callVC only after the user answered the call
                __weak NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
                __block id token = [[NSNotificationCenter defaultCenter] addObserverForName:kMXCallStateDidChange
                                                                                     object:mxCall
                                                                                      queue:nil
                                                                                 usingBlock:^(NSNotification * _Nonnull note) {
                                                                                     MXCall *call = (MXCall *)note.object;

                                                                                     NSLog(@"[AppDelegate] call.state: %@", call);

                                                                                     if (call.state == MXCallStateCreateAnswer)
                                                                                     {
                                                                                         [notificationCenter removeObserver:token];

                                                                                         NSLog(@"[AppDelegate] presentCallViewController");
                                                                                         [self presentCallViewController:NO completion:nil];
                                                                                     }
                                                                                 }];
            }
            else
            {
                [self presentCallViewController:YES completion:nil];
            }
        }
    }];
}

- (void)handleLaunchAnimation
{
    MXSession *mainSession = self.mxSessions.firstObject;
    
    if (mainSession)
    {
        BOOL isLaunching = NO;
        
        switch (mainSession.state)
        {
            case MXSessionStateClosed:
            case MXSessionStateInitialised:
                isLaunching = YES;
                break;
            case MXSessionStateStoreDataReady:
            case MXSessionStateSyncInProgress:
                // Stay in launching during the first server sync if the store is empty.
                isLaunching = (mainSession.rooms.count == 0 && launchScreenContainerView.superview);
            default:
                break;
        }
        
        if (isLaunching)
        {
            UIWindow *window = [[UIApplication sharedApplication] keyWindow];
            if (!launchScreenContainerView.superview && window)
            {
                [window addSubview:launchScreenContainerView];
                launchAnimationStart = [NSDate date];
            }
            
            return;
        }
    }
    
    if (launchScreenContainerView.superview)
    {
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:launchAnimationStart];
        NSLog(@"[AppDelegate] LaunchScreen was shown for %.3fms", duration * 1000);

        // Track it on our analytics
        [[Analytics sharedInstance] trackLaunchScreenDisplayDuration:duration];

        // TODO: Send durationMs to Piwik
        // Such information should be the same on all platforms
        
        [launchScreenContainerView removeFromSuperview];
    }
}

- (void)enableCallKit:(BOOL)enable forCallManager:(MXCallManager *)callManager
{
    if (enable)
    {
        // Create adapter for Riot
        MXCallKitConfiguration *callKitConfiguration = [[MXCallKitConfiguration alloc] init];
        callKitConfiguration.iconName = @"tchap_icon_callkit";
        MXCallKitAdapter *callKitAdapter = [[MXCallKitAdapter alloc] initWithConfiguration:callKitConfiguration];
        
        id<MXCallAudioSessionConfigurator> audioSessionConfigurator;
        
#ifdef CALL_STACK_JINGLE
        audioSessionConfigurator = [[MXJingleCallAudioSessionConfigurator alloc] init];
#endif
        
        callKitAdapter.audioSessionConfigurator = audioSessionConfigurator;
        
        callManager.callKitAdapter = callKitAdapter;
    }
    else
    {
        callManager.callKitAdapter = nil;
    }
}

- (void)enableLocalNotificationsFromMatrixSession:(MXSession*)mxSession
{
    // Prepare listener block.
    MXWeakify(self);
    MXOnNotification notificationListenerBlock = ^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule) {
        MXStrongifyAndReturnIfNil(self);
        
        // Ignore this event if the app is not running in background.
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground)
        {
            return;
        }

        // If the app is doing an initial sync, ignore all events from which we
        // did not receive a notification from APNS/PushKit
        if (!mxSession.isEventStreamInitialised && !self->incomingPushPayloads[event.eventId])
        {
            NSLog(@"[AppDelegate][Push] enableLocalNotificationsFromMatrixSession: Initial sync in progress. Ignore event %@", event.eventId);
            return;
        }

        // Sanity check
        if (event.eventId && event.roomId && rule)
        {
            NSLog(@"[AppDelegate][Push] enableLocalNotificationsFromMatrixSession: got event %@ to notify", event.eventId);

            // Check whether this event corresponds to a pending push for this session.
            NSUInteger index = [self.incomingPushEventIds[@(mxSession.hash)] indexOfObject:event.eventId];
            if (index != NSNotFound)
            {
                // Remove it from the pending list.
                [self.incomingPushEventIds[@(mxSession.hash)] removeObjectAtIndex:index];
            }
            
            // Add it to the list of the events to notify.
            [self->eventsToNotify[@(mxSession.hash)] addObject:@{
                                                           @"event_id": event.eventId,
                                                           @"room_id": event.roomId,
                                                           @"push_rule": rule
                                                           }];
        }
        else
        {
            NSLog(@"[AppDelegate][Push] enableLocalNotificationsFromMatrixSession: WARNING: wrong event to notify %@ %@ %@", event, event.roomId, rule);
        }
    };
    
    eventsToNotify[@(mxSession.hash)] = [NSMutableArray array];
    [mxSession.notificationCenter listenToNotifications:notificationListenerBlock];
    notificationListenerBlocks[@(mxSession.hash)] = notificationListenerBlock;
}

- (void)disableLocalNotificationsFromMatrixSession:(MXSession*)mxSession
{
    // Stop listening to notification of this session
    [mxSession.notificationCenter removeListener:notificationListenerBlocks[@(mxSession.hash)]];
    [notificationListenerBlocks removeObjectForKey:@(mxSession.hash)];
    [eventsToNotify removeObjectForKey:@(mxSession.hash)];
}

#pragma mark -

/**
 Check the existence of device id.
 */
- (void)checkDeviceId:(MXSession*)mxSession
{
    // In case of the app update for the e2e encryption, the app starts with
    // no device id provided by the homeserver.
    // Ask the user to login again in order to enable e2e. Ask it once
    if (!isErrorNotificationSuspended && ![[NSUserDefaults standardUserDefaults] boolForKey:@"deviceIdAtStartupChecked"])
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"deviceIdAtStartupChecked"];
        
        // Check if there is a device id
        if (!mxSession.matrixRestClient.credentials.deviceId)
        {
            NSLog(@"WARNING: The user has no device. Prompt for login again");
            
            NSString *msg = NSLocalizedStringFromTable(@"e2e_enabling_on_app_update", @"Vector", nil);
            
            __weak typeof(self) weakSelf = self;
            [_errorNotification dismissViewControllerAnimated:NO completion:nil];
            _errorNotification = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
            
            [_errorNotification addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"later"]
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * action) {
                                                                     
                                                                     if (weakSelf)
                                                                     {
                                                                         typeof(self) self = weakSelf;
                                                                         self->_errorNotification = nil;
                                                                     }
                                                                     
                                                                 }]];
            
            [_errorNotification addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * action) {
                                                                     
                                                                     if (weakSelf)
                                                                     {
                                                                         typeof(self) self = weakSelf;
                                                                         self->_errorNotification = nil;
                                                                         
                                                                         [self logoutWithConfirmation:NO completion:nil];
                                                                     }
                                                                     
                                                                 }]];
            
            // Prompt the user
            [_errorNotification mxk_setAccessibilityIdentifier:@"AppDelegateErrorAlert"];
            [self showNotificationAlert:_errorNotification];
        }
    }
}

#pragma mark - Matrix Accounts handling

- (void)selectMatrixAccount:(void (^)(MXKAccount *selectedAccount))onSelection
{
    NSArray *mxAccounts = [MXKAccountManager sharedManager].activeAccounts;
    
    if (mxAccounts.count == 1)
    {
        if (onSelection)
        {
            onSelection(mxAccounts.firstObject);
        }
    }
    else if (mxAccounts.count > 1)
    {
        [accountPicker dismissViewControllerAnimated:NO completion:nil];
        
        accountPicker = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"select_account"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        __weak typeof(self) weakSelf = self;
        for(MXKAccount *account in mxAccounts)
        {
            [accountPicker addAction:[UIAlertAction actionWithTitle:account.mxCredentials.userId
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
                                                                
                                                                if (weakSelf)
                                                                {
                                                                    typeof(self) self = weakSelf;
                                                                    self->accountPicker = nil;
                                                                    
                                                                    if (onSelection)
                                                                    {
                                                                        onSelection(account);
                                                                    }
                                                                }
                                                                
                                                            }]];
        }
        
        [accountPicker addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                          style:UIAlertActionStyleCancel
                                                        handler:^(UIAlertAction * action) {
                                                            
                                                            if (weakSelf)
                                                            {
                                                                typeof(self) self = weakSelf;
                                                                self->accountPicker = nil;
                                                                
                                                                if (onSelection)
                                                                {
                                                                    onSelection(nil);
                                                                }
                                                            }
                                                            
                                                        }]];
        
        [self showNotificationAlert:accountPicker];
    }
}

#pragma mark - Contacts handling

- (void)refreshLocalContacts
{
    // Check whether the application is allowed to access the local contacts.
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized)
    {
        // Check the user permission for syncing local contacts. This permission was handled independently on previous application version.
        if (![MXKAppSettings standardAppSettings].syncLocalContacts)
        {
            // Check whether it was not requested yet.
            if (![MXKAppSettings standardAppSettings].syncLocalContactsPermissionRequested)
            {
                [MXKAppSettings standardAppSettings].syncLocalContactsPermissionRequested = YES;
                
                UIViewController *viewController = self.window.rootViewController.presentedViewController;
                if (!viewController)
                {
                    viewController = self.window.rootViewController;
                }
                
                [MXKContactManager requestUserConfirmationForLocalContactsSyncInViewController:viewController completionHandler:^(BOOL granted) {
                    
                    if (granted)
                    {
                        // Allow local contacts sync in order to discover matrix users.
                        [MXKAppSettings standardAppSettings].syncLocalContacts = YES;
                    }
                    
                }];
            }
        }
        
        // Refresh the local contacts list.
        [[MXKContactManager sharedManager] refreshLocalContacts];
    }
}

#pragma mark - MXKCallViewControllerDelegate

- (void)dismissCallViewController:(MXKCallViewController *)callViewController completion:(void (^)())completion
{
    if (currentCallViewController && callViewController == currentCallViewController)
    {
        if (callViewController.isBeingPresented)
        {
            // Here the presentation of the call view controller is in progress
            // Postpone the dismiss
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self dismissCallViewController:callViewController completion:completion];
            });
        }
        // Check whether the call view controller is actually presented
        else if (callViewController.presentingViewController)
        {
            BOOL callIsEnded = (callViewController.mxCall.state == MXCallStateEnded);
            NSLog(@"Call view controller is dismissed (%d)", callIsEnded);
            
            [callViewController dismissViewControllerAnimated:YES completion:^{
                
                if (!callIsEnded)
                {
                    NSString *btnTitle = [NSString stringWithFormat:NSLocalizedStringFromTable(@"active_call_details", @"Vector", nil), callViewController.callerNameLabel.text];
                    [self addCallStatusBar:btnTitle];
                }
                
                if (completion)
                {
                    completion();
                }
                
            }];
            
            if (callIsEnded)
            {
                [self removeCallStatusBar];
                
                // Release properly
                [currentCallViewController destroy];
                currentCallViewController = nil;
            }
        }
        else if (_callStatusBarWindow)
        {
            // Here the call view controller was not presented.
            NSLog(@"Call view controller was not presented");
            
            // Workaround to manage the "back to call" banner: present temporarily the call screen.
            // This will correctly manage the navigation bar layout.
            [self presentCallViewController:YES completion:^{
                
                [self dismissCallViewController:currentCallViewController completion:completion];
                
            }];
        }
    }
}

#pragma mark - Jitsi call

- (void)displayJitsiViewControllerWithWidget:(Widget*)jitsiWidget andVideo:(BOOL)video
{
    if (!_jitsiViewController && !currentCallViewController)
    {
        _jitsiViewController = [JitsiViewController jitsiViewController];

        [_jitsiViewController openWidget:jitsiWidget withVideo:video success:^{

            _jitsiViewController.delegate = self;
            [self presentJitsiViewController:nil];
        
        } failure:^(NSError *error) {

            _jitsiViewController = nil;

            NSError *theError = [NSError errorWithDomain:@""
                                                    code:0
                                                userInfo:@{
                                                        NSLocalizedDescriptionKey: NSLocalizedStringFromTable(@"call_jitsi_error", @"Vector", nil)
                                                        }];
            [self showErrorAsAlert:theError];
        }];
    }
    else
    {
        NSError *error = [NSError errorWithDomain:@""
                                    code:0
                                userInfo:@{
                                           NSLocalizedDescriptionKey: NSLocalizedStringFromTable(@"call_already_displayed", @"Vector", nil)
                                           }];
        [self showErrorAsAlert:error];
    }
}

- (void)presentJitsiViewController:(void (^)())completion
{
    [self removeCallStatusBar];

    if (_jitsiViewController)
    {
        if (self.window.rootViewController.presentedViewController)
        {
            [self.window.rootViewController.presentedViewController presentViewController:_jitsiViewController animated:YES completion:completion];
        }
        else
        {
            [self.window.rootViewController presentViewController:_jitsiViewController animated:YES completion:completion];
        }
    }
}

- (void)jitsiViewController:(JitsiViewController *)jitsiViewController dismissViewJitsiController:(void (^)())completion
{
    if (jitsiViewController == _jitsiViewController)
    {
        [_jitsiViewController dismissViewControllerAnimated:YES completion:completion];
        _jitsiViewController = nil;

        [self removeCallStatusBar];
    }
}

- (void)jitsiViewController:(JitsiViewController *)jitsiViewController goBackToApp:(void (^)())completion
{
    if (jitsiViewController == _jitsiViewController)
    {
        [_jitsiViewController dismissViewControllerAnimated:YES completion:^{

            MXRoom *room = [_jitsiViewController.widget.mxSession roomWithRoomId:_jitsiViewController.widget.roomId];
            NSString *btnTitle = [NSString stringWithFormat:NSLocalizedStringFromTable(@"active_call_details", @"Vector", nil), room.summary.displayname];
            [self addCallStatusBar:btnTitle];

            if (completion)
            {
                completion();
            }
        }];
    }
}


#pragma mark - Call status handling

- (void)addCallStatusBar:(NSString*)buttonTitle
{
    // Add a call status bar
    CGSize topBarSize = CGSizeMake([[UIScreen mainScreen] bounds].size.width, CALL_STATUS_BAR_HEIGHT);
    
    _callStatusBarWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, topBarSize.width, topBarSize.height)];
    _callStatusBarWindow.windowLevel = UIWindowLevelStatusBar;
    
    // Create statusBarButton
    _callStatusBarButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _callStatusBarButton.frame = CGRectMake(0, 0, topBarSize.width, topBarSize.height);
    
    [_callStatusBarButton setTitle:buttonTitle forState:UIControlStateNormal];
    [_callStatusBarButton setTitle:buttonTitle forState:UIControlStateHighlighted];
    _callStatusBarButton.titleLabel.textColor = kVariant2PrimaryTextColor;
    
    if ([UIFont respondsToSelector:@selector(systemFontOfSize:weight:)])
    {
        _callStatusBarButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    }
    else
    {
        _callStatusBarButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    }
    
    [_callStatusBarButton setBackgroundColor:kVariant2PrimaryBgColor];
    [_callStatusBarButton addTarget:self action:@selector(onCallStatusBarButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    // Place button into the new window
    [_callStatusBarButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_callStatusBarWindow addSubview:_callStatusBarButton];
    
    // Force callStatusBarButton to fill the window (to handle auto-layout in case of screen rotation)
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:_callStatusBarButton
                                                                       attribute:NSLayoutAttributeWidth
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:_callStatusBarWindow
                                                                       attribute:NSLayoutAttributeWidth
                                                                      multiplier:1.0
                                                                        constant:0];
    
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:_callStatusBarButton
                                                                        attribute:NSLayoutAttributeHeight
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:_callStatusBarWindow
                                                                        attribute:NSLayoutAttributeHeight
                                                                       multiplier:1.0
                                                                         constant:0];
    
    [NSLayoutConstraint activateConstraints:@[widthConstraint, heightConstraint]];
    
    _callStatusBarWindow.hidden = NO;
    [self statusBarDidChangeFrame];
    
    // We need to listen to the system status bar size change events to refresh the root controller frame.
    // Else the navigation bar position will be wrong.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(statusBarDidChangeFrame)
                                                 name:UIApplicationDidChangeStatusBarFrameNotification
                                               object:nil];
}

- (void)removeCallStatusBar
{
    if (_callStatusBarWindow)
    {
        // No more need to listen to system status bar changes
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
        
        // Hide & destroy it
        _callStatusBarWindow.hidden = YES;
        [_callStatusBarButton removeFromSuperview];
        _callStatusBarButton = nil;
        _callStatusBarWindow = nil;
        
        [self statusBarDidChangeFrame];
    }
}

- (void)onCallStatusBarButtonPressed
{
    if (currentCallViewController)
    {
        [self presentCallViewController:YES completion:nil];
    }
    else if (_jitsiViewController)
    {
        [self presentJitsiViewController:nil];
    }
}

- (void)presentCallViewController:(BOOL)animated completion:(void (^)())completion
{
    [self removeCallStatusBar];
    
    if (currentCallViewController)
    {
        if (self.window.rootViewController.presentedViewController)
        {
            [self.window.rootViewController.presentedViewController presentViewController:currentCallViewController animated:animated completion:completion];
        }
        else
        {
            [self.window.rootViewController presentViewController:currentCallViewController animated:animated completion:completion];
        }
    }
}

- (void)statusBarDidChangeFrame
{
    UIApplication *app = [UIApplication sharedApplication];
    UIViewController *rootController = app.keyWindow.rootViewController;
    
    // Refresh the root view controller frame
    CGRect rootControllerFrame = [[UIScreen mainScreen] bounds];
    
    if (_callStatusBarWindow)
    {
        UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
        
        switch (statusBarOrientation)
        {
            case UIInterfaceOrientationLandscapeLeft:
            {
                _callStatusBarWindow.frame = CGRectMake(-rootControllerFrame.size.width / 2, -CALL_STATUS_BAR_HEIGHT / 2, rootControllerFrame.size.width, CALL_STATUS_BAR_HEIGHT);
                _callStatusBarWindow.transform = CGAffineTransformMake(0, -1, 1, 0, CALL_STATUS_BAR_HEIGHT / 2, rootControllerFrame.size.width / 2);
                break;
            }
            case UIInterfaceOrientationLandscapeRight:
            {
                _callStatusBarWindow.frame = CGRectMake(-rootControllerFrame.size.width / 2, -CALL_STATUS_BAR_HEIGHT / 2, rootControllerFrame.size.width, CALL_STATUS_BAR_HEIGHT);
                _callStatusBarWindow.transform = CGAffineTransformMake(0, 1, -1, 0, rootControllerFrame.size.height - CALL_STATUS_BAR_HEIGHT / 2, rootControllerFrame.size.width / 2);
                break;
            }
            default:
            {
                _callStatusBarWindow.transform = CGAffineTransformIdentity;
                _callStatusBarWindow.frame = CGRectMake(0, 0, rootControllerFrame.size.width, CALL_STATUS_BAR_HEIGHT);
                break;
            }
        }
        
        // Apply the vertical offset due to call status bar
        rootControllerFrame.origin.y = CALL_STATUS_BAR_HEIGHT;
        rootControllerFrame.size.height -= CALL_STATUS_BAR_HEIGHT;
    }
    
    rootController.view.frame = rootControllerFrame;
    if (rootController.presentedViewController)
    {
        rootController.presentedViewController.view.frame = rootControllerFrame;
    }
    [rootController.view setNeedsLayout];
}

#pragma mark - Status Bar Tap handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.window];
    
    CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    
    if (CGRectContainsPoint(statusBarFrame, point))
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kAppDelegateDidTapStatusBarNotification object:nil];
    }
}

#pragma mark - No call support
/**
 Display a "Call not supported" alert when the session receives a call invitation.
 
 @param mxSession the session to spy
 */
- (void)enableNoVoIPOnMatrixSession:(MXSession*)mxSession
{
    // Listen to call events
    callEventsListeners[@(mxSession.hash)] =
    [mxSession listenToEventsOfTypes:@[
                                       kMXEventTypeStringCallInvite,
                                       kMXEventTypeStringCallCandidates,
                                       kMXEventTypeStringCallAnswer,
                                       kMXEventTypeStringCallHangup
                                       ]
                             onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {
                                 
                                 if (MXTimelineDirectionForwards == direction)
                                 {
                                     switch (event.eventType)
                                     {
                                         case MXEventTypeCallInvite:
                                         {
                                             if (noCallSupportAlert)
                                             {
                                                 [noCallSupportAlert dismissViewControllerAnimated:NO completion:nil];
                                             }
                                             
                                             MXCallInviteEventContent *callInviteEventContent = [MXCallInviteEventContent modelFromJSON:event.content];
                                             
                                             // Sanity and invite expiration checks
                                             if (!callInviteEventContent || event.age >= callInviteEventContent.lifetime)
                                             {
                                                 return;
                                             }
                                             
                                             MXUser *caller = [mxSession userWithUserId:event.sender];
                                             NSString *callerDisplayname = caller.displayname;
                                             if (!callerDisplayname.length)
                                             {
                                                 callerDisplayname = event.sender;
                                             }
                                             
                                             NSString *appDisplayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
                                             
                                             NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"no_voip", @"Vector", nil), callerDisplayname, appDisplayName];
                                             
                                             noCallSupportAlert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"no_voip_title", @"Vector", nil)
                                                                                                      message:message
                                                                                               preferredStyle:UIAlertControllerStyleAlert];
                                             
                                             __weak typeof(self) weakSelf = self;
                                             
                                             [noCallSupportAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ignore"]
                                                                                                    style:UIAlertActionStyleDefault
                                                                                                  handler:^(UIAlertAction * action) {
                                                                                                      
                                                                                                      if (weakSelf)
                                                                                                      {
                                                                                                          typeof(self) self = weakSelf;
                                                                                                          self->noCallSupportAlert = nil;
                                                                                                      }
                                                                                                      
                                                                                                  }]];
                                             
                                             [noCallSupportAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"reject_call"]
                                                                                                    style:UIAlertActionStyleDefault
                                                                                                  handler:^(UIAlertAction * action) {
                                                                                                      
                                                                                                      // Reject the call by sending the hangup event
                                                                                                      NSDictionary *content = @{
                                                                                                                                @"call_id": callInviteEventContent.callId,
                                                                                                                                @"version": @(0)
                                                                                                                                };
                                                                                                      
                                                                                                      [mxSession.matrixRestClient sendEventToRoom:event.roomId eventType:kMXEventTypeStringCallHangup content:content txnId:nil success:nil failure:^(NSError *error) {
                                                                                                          NSLog(@"[AppDelegate] enableNoVoIPOnMatrixSession: ERROR: Cannot send m.call.hangup event.");
                                                                                                      }];
                                                                                                      
                                                                                                      if (weakSelf)
                                                                                                      {
                                                                                                          typeof(self) self = weakSelf;
                                                                                                          self->noCallSupportAlert = nil;
                                                                                                      }
                                                                                                      
                                                                                                  }]];
                                             
                                             [self showNotificationAlert:noCallSupportAlert];
                                             break;
                                         }
                                             
                                         case MXEventTypeCallAnswer:
                                         case MXEventTypeCallHangup:
                                             // The call has ended. The alert is no more needed.
                                             if (noCallSupportAlert)
                                             {
                                                 [noCallSupportAlert dismissViewControllerAnimated:YES completion:nil];
                                                 noCallSupportAlert = nil;
                                             }
                                             break;
                                             
                                         default:
                                             break;
                                     }
                                 }
                                 
                             }];
    
}

- (void)disableNoVoIPOnMatrixSession:(MXSession*)mxSession
{
    // Stop listening to the call events of this session 
    [mxSession removeListener:callEventsListeners[@(mxSession.hash)]];
    [callEventsListeners removeObjectForKey:@(mxSession.hash)];
}

#pragma mark - Incoming room key requests handling

- (void)enableRoomKeyRequestObserver:(MXSession*)mxSession
{
    roomKeyRequestObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:kMXCryptoRoomKeyRequestNotification
                                                      object:mxSession.crypto
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *notif)
     {
         [self checkPendingRoomKeyRequestsInSession:mxSession];
     }];

    roomKeyRequestCancellationObserver  =
    [[NSNotificationCenter defaultCenter] addObserverForName:kMXCryptoRoomKeyRequestCancellationNotification
                                                      object:mxSession.crypto
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *notif)
     {
         [self checkPendingRoomKeyRequestsInSession:mxSession];
     }];
}

- (void)disableRoomKeyRequestObserver:(MXSession*)mxSession
{
    if (roomKeyRequestObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomKeyRequestObserver];
        roomKeyRequestObserver = nil;
    }

    if (roomKeyRequestCancellationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomKeyRequestCancellationObserver];
        roomKeyRequestCancellationObserver = nil;
    }
}

// Check if a key share dialog must be displayed for the given session
- (void)checkPendingRoomKeyRequestsInSession:(MXSession*)mxSession
{
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
    {
        NSLog(@"[AppDelegate] checkPendingRoomKeyRequestsInSession called while the app is not active. Ignore it.");
        return;
    }

    [mxSession.crypto pendingKeyRequests:^(MXUsersDevicesMap<NSArray<MXIncomingRoomKeyRequest *> *> *pendingKeyRequests) {

        NSLog(@"[AppDelegate] checkPendingRoomKeyRequestsInSession: pendingKeyRequests.count: %@. Already displayed: %@",
              @(pendingKeyRequests.count),
              roomKeyRequestViewController ? @"YES" : @"NO");

        if (roomKeyRequestViewController)
        {
            // Check if the current RoomKeyRequestViewController is still valid
            MXSession *currentMXSession = roomKeyRequestViewController.mxSession;
            NSString *currentUser = roomKeyRequestViewController.device.userId;
            NSString *currentDevice = roomKeyRequestViewController.device.deviceId;

            NSArray<MXIncomingRoomKeyRequest *> *currentPendingRequest = [pendingKeyRequests objectForDevice:currentDevice forUser:currentUser];

            if (currentMXSession == mxSession && currentPendingRequest.count == 0)
            {
                NSLog(@"[AppDelegate] checkPendingRoomKeyRequestsInSession: Cancel current dialog");

                // The key request has been probably cancelled, remove the popup
                [roomKeyRequestViewController hide];
                roomKeyRequestViewController = nil;
            }
        }

        if (!roomKeyRequestViewController && pendingKeyRequests.count)
        {
            // Pick the first coming user/device pair
            NSString *userId = pendingKeyRequests.userIds.firstObject;
            NSString *deviceId = [pendingKeyRequests deviceIdsForUser:userId].firstObject;

            // Give the client a chance to refresh the device list
            [mxSession.crypto downloadKeys:@[userId] forceDownload:NO success:^(MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap) {

                MXDeviceInfo *deviceInfo = [usersDevicesInfoMap objectForDevice:deviceId forUser:userId];
                if (deviceInfo)
                {
                    BOOL wasNewDevice = (deviceInfo.verified == MXDeviceUnknown);

                    void (^openDialog)() = ^void()
                    {
                        NSLog(@"[AppDelegate] checkPendingRoomKeyRequestsInSession: Open dialog for %@", deviceInfo);

                        roomKeyRequestViewController = [[RoomKeyRequestViewController alloc] initWithDeviceInfo:deviceInfo wasNewDevice:wasNewDevice andMatrixSession:mxSession onComplete:^{

                            roomKeyRequestViewController = nil;

                            // Check next pending key request, if any
                            [self checkPendingRoomKeyRequests];
                        }];

                        [roomKeyRequestViewController show];
                    };

                    // If the device was new before, it's not any more.
                    if (wasNewDevice)
                    {
                        [mxSession.crypto setDeviceVerification:MXDeviceUnverified forDevice:deviceId ofUser:userId success:openDialog failure:nil];
                    }
                    else
                    {
                        openDialog();
                    }
                }
                else
                {
                    NSLog(@"[AppDelegate] checkPendingRoomKeyRequestsInSession: No details found for device %@:%@", userId, deviceId);

                    // Ignore this device to avoid to loop on it
                    [mxSession.crypto ignoreAllPendingKeyRequestsFromUser:userId andDevice:deviceId onComplete:^{
                        // And check next requests
                        [self checkPendingRoomKeyRequests];
                    }];
                }

            } failure:^(NSError *error) {
                // Retry later
                NSLog(@"[AppDelegate] checkPendingRoomKeyRequestsInSession: Failed to download device keys. Retry");
                [self checkPendingRoomKeyRequests];
            }];
        }
    }];
}

// Check all opened MXSessions for key share dialog 
- (void)checkPendingRoomKeyRequests
{
    for (MXSession *mxSession in mxSessionArray)
    {
        [self checkPendingRoomKeyRequestsInSession:mxSession];
    }
}

#pragma mark - GDPR consent

// Observe user GDPR consent not given
- (void)registerUserConsentNotGivenNotification
{
    [NSNotificationCenter.defaultCenter addObserverForName:kMXHTTPClientUserConsentNotGivenErrorNotification
                                                    object:nil
                                                     queue:[NSOperationQueue mainQueue]
                                                usingBlock:^(NSNotification *notification)
    {
        NSString *consentURI = notification.userInfo[kMXHTTPClientUserConsentNotGivenErrorNotificationConsentURIKey];
        if (consentURI
            && self.gdprConsentNotGivenAlertController.presentingViewController == nil
            && self.gdprConsentController.presentingViewController == nil)
        {
            self.gdprConsentNotGivenAlertController = nil;
            self.gdprConsentController = nil;
            
            UIViewController *presentingViewController = self.window.rootViewController.presentedViewController ?: self.window.rootViewController;
            
            __weak typeof(self) weakSelf = self;
            
            NSString *alertMessage = NSLocalizedStringFromTable(@"gdpr_consent_not_given_alert_message", @"Tchap", nil);
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"settings_term_conditions", @"Vector", nil)                                        
                                                                           message:alertMessage
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"gdpr_consent_not_given_alert_review_now_action", @"Vector", nil)
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * action) {
                                                        
                                                        typeof(weakSelf) strongSelf = weakSelf;
                                                        
                                                        if (strongSelf)
                                                        {
                                                            [strongSelf presentGDPRConsentFromViewController:presentingViewController consentURI:consentURI];
                                                        }
                                                    }]];
            
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"later", @"Vector", nil)
                                                      style:UIAlertActionStyleCancel
                                                    handler:nil]];
            
            [presentingViewController presentViewController:alert animated:YES completion:nil];
            
            self.gdprConsentNotGivenAlertController = alert;
        }
    }];
}

- (void)presentGDPRConsentFromViewController:(UIViewController*)viewController consentURI:(NSString*)consentURI
{
    GDPRConsentViewController *gdprConsentViewController = [[GDPRConsentViewController alloc] initWithURL:consentURI];    
    
    UIBarButtonItem *closeBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"close"]
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(dismissGDPRConsent)];
    
    gdprConsentViewController.navigationItem.leftBarButtonItem = closeBarButtonItem;
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:gdprConsentViewController];
    
    [viewController presentViewController:navigationController animated:YES completion:nil];
    
    self.gdprConsentController = navigationController;
    
    gdprConsentViewController.delegate = self;
}

- (void)dismissGDPRConsent
{    
    [self.gdprConsentController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - GDPRConsentViewControllerDelegate

- (void)gdprConsentViewControllerDidConsentToGDPRWithSuccess:(GDPRConsentViewController *)gdprConsentViewController
{
    MXSession *session = mxSessionArray.firstObject;

    // Leave the GDPR consent right now
    [self dismissGDPRConsent];

    // And create the room with riot bot in //
    self.onBoardingManager = [[OnBoardingManager alloc] initWithSession:session];
    
    MXWeakify(self);
    void (^createRiotBotDMcompletion)(void) = ^() {
        MXStrongifyAndReturnIfNil(self);

        self.onBoardingManager = nil;
    };
    
    [self.onBoardingManager createRiotBotDirectMessageIfNeededWithSuccess:^{
        createRiotBotDMcompletion();
    } failure:^(NSError * _Nonnull error) {
        createRiotBotDMcompletion();
    }];
}

#pragma mark - Settings

+ (void)setupUserDefaults
{
    // Register "Tchap-Defaults.plist" default values
    NSString* userDefaults = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UserDefaults"];
    NSString *defaultsPathFromApp = [[NSBundle mainBundle] pathForResource:userDefaults ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPathFromApp];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

@end
