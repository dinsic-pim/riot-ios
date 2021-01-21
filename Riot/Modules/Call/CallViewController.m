/*
 Copyright 2016 OpenMarket Ltd
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

#import "CallViewController.h"

#import "Riot-Swift.h"

#import "AvatarGenerator.h"

#import "UsersDevicesViewController.h"

#import "RiotNavigationController.h"

#import "IncomingCallView.h"

@interface CallViewController () <PictureInPicturable, DialpadViewControllerDelegate>
{
    // Current alert (if any).
    UIAlertController *currentAlert;
    
    // Flag to compute self.shouldPromptForStunServerFallback
    BOOL promptForStunServerFallback;
}

@property (nonatomic, strong) id<Theme> overriddenTheme;
@property (nonatomic, assign) BOOL inPiP;

@property (nonatomic, strong) CustomSizedPresentationController *customSizedPresentationController;

@end

@implementation CallViewController

- (void)finalizeInit
{
    [super finalizeInit];
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];

    promptForStunServerFallback = NO;
    _shouldPromptForStunServerFallback = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Back button
    
    UIImage *backButtonImage = [UIImage imageNamed:@"back_icon"];
    [self.backToAppButton setImage:backButtonImage forState:UIControlStateNormal];
    [self.backToAppButton setImage:backButtonImage forState:UIControlStateHighlighted];
    
    // Camera switch
    
    UIImage *cameraSwitchButtonImage = [UIImage imageNamed:@"camera_switch"];
    [self.cameraSwitchButton setImage:cameraSwitchButtonImage forState:UIControlStateNormal];
    [self.cameraSwitchButton setImage:cameraSwitchButtonImage forState:UIControlStateHighlighted];
    
    // Audio mute
    
    UIImage *audioMuteOffButtonImage = [UIImage imageNamed:@"call_audio_mute_off_icon"];
    UIImage *audioMuteOnButtonImage = [UIImage imageNamed:@"call_audio_mute_on_icon"];
    
    [self.audioMuteButton setImage:audioMuteOffButtonImage forState:UIControlStateNormal];
    [self.audioMuteButton setImage:audioMuteOffButtonImage forState:UIControlStateHighlighted];
    [self.audioMuteButton setImage:audioMuteOnButtonImage forState:UIControlStateSelected];
    
    // Video mute
    
    UIImage *videoOffButtonImage = [UIImage imageNamed:@"call_video_mute_off_icon"];
    UIImage *videoOnButtonImage = [UIImage imageNamed:@"call_video_mute_on_icon"];
    
    [self.videoMuteButton setImage:videoOffButtonImage forState:UIControlStateNormal];
    [self.videoMuteButton setImage:videoOffButtonImage forState:UIControlStateHighlighted];
    [self.videoMuteButton setImage:videoOnButtonImage forState:UIControlStateSelected];
    
    //  More
    
    UIImage *moreButtonImage = [UIImage imageNamed:@"call_more_icon"];
    
    [self.moreButton setImage:moreButtonImage forState:UIControlStateNormal];
    
    // Hang up
    
    UIImage *hangUpButtonImage = [UIImage imageNamed:@"call_hangup_large"];
    
    [self.endCallButton setTitle:nil forState:UIControlStateNormal];
    [self.endCallButton setTitle:nil forState:UIControlStateHighlighted];
    [self.endCallButton setImage:hangUpButtonImage forState:UIControlStateNormal];
    [self.endCallButton setImage:hangUpButtonImage forState:UIControlStateHighlighted];
    
    [self updateLocalPreviewLayout];
    
    [self configureUserInterface];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return self.overriddenTheme.statusBarStyle;
}

- (void)configureUserInterface
{
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = self.overriddenTheme.userInterfaceStyle;
    }
    
    [self.overriddenTheme applyStyleOnNavigationBar:self.navigationController.navigationBar];

    self.barTitleColor = self.overriddenTheme.textPrimaryColor;
    self.activityIndicator.backgroundColor = self.overriddenTheme.overlayBackgroundColor;
    
    self.backToAppButton.tintColor = [UIColor whiteColor];
    self.cameraSwitchButton.tintColor = [UIColor whiteColor];
    self.callerNameLabel.textColor = [UIColor whiteColor];
    self.callStatusLabel.textColor = [UIColor whiteColor];
    [self.resumeButton setTitleColor:self.overriddenTheme.tintColor
                            forState:UIControlStateNormal];
    
    self.localPreviewContainerView.layer.borderColor = self.overriddenTheme.tintColor.CGColor;
    self.localPreviewContainerView.layer.borderWidth = 2;
    self.localPreviewContainerView.layer.cornerRadius = 5;
    self.localPreviewContainerView.clipsToBounds = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    [super viewWillDisappear:animated];
}

#pragma mark - override MXKViewController

- (UIView *)createIncomingCallView
{
    if ([MXCallKitAdapter callKitAvailable])
    {
        return nil;
    }
    
    NSString *callInfo;
    if (self.mxCall.isVideoCall)
        callInfo = NSLocalizedStringFromTable(@"call_incoming_video", @"Vector", nil);
    else
        callInfo = NSLocalizedStringFromTable(@"call_incoming_voice", @"Vector", nil);
    
    IncomingCallView *incomingCallView = [[IncomingCallView alloc] initWithCallerAvatar:self.peer.avatarUrl
                                                                           mediaManager:self.mainSession.mediaManager
                                                                       placeholderImage:self.picturePlaceholder
                                                                             callerName:self.peer.displayname
                                                                               callInfo:callInfo];
    
    // Incoming call is retained by call vc so use weak to avoid retain cycle
    __weak typeof(self) weakSelf = self;
    
    incomingCallView.onAnswer = ^{
        [weakSelf onButtonPressed:weakSelf.answerCallButton];
    };
    
    incomingCallView.onReject = ^{
        [weakSelf onButtonPressed:weakSelf.rejectCallButton];
    };
    
    return incomingCallView;
}

#pragma mark - MXCallDelegate

- (void)call:(MXCall *)call stateDidChange:(MXCallState)state reason:(MXEvent *)event
{
    [super call:call stateDidChange:state reason:event];

    [self checkStunServerFallbackWithCallState:state];
}

- (void)call:(MXCall *)call didEncounterError:(NSError *)error reason:(MXCallHangupReason)reason
{
    if ([error.domain isEqualToString:MXEncryptingErrorDomain]
        && error.code == MXEncryptingErrorUnknownDeviceCode)
    {
        // There are unknown devices, check what the user wants to do
        __weak __typeof(self) weakSelf = self;
        
        MXUsersDevicesMap<MXDeviceInfo*> *unknownDevices = error.userInfo[MXEncryptingErrorUnknownDeviceDevicesKey];
        
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        
        currentAlert = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"unknown_devices_alert_title"]
                                                           message:[NSBundle mxk_localizedStringForKey:@"unknown_devices_alert"]
                                                    preferredStyle:UIAlertControllerStyleAlert];
        
        [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"unknown_devices_verify"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               self->currentAlert = nil;
                                                               
                                                               // Get the UsersDevicesViewController from the storyboard
                                                               UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
                                                               UsersDevicesViewController *usersDevicesViewController = [storyboard instantiateViewControllerWithIdentifier:@"UsersDevicesViewControllerStoryboardId"];
                                                               
                                                               [usersDevicesViewController displayUsersDevices:unknownDevices andMatrixSession:self.mainSession onComplete:^(BOOL doneButtonPressed) {
                                                                   
                                                                   if (doneButtonPressed)
                                                                   {
                                                                       // Retry the call
                                                                       if (call.isIncoming)
                                                                       {
                                                                           [call answer];
                                                                       }
                                                                       else
                                                                       {
                                                                           [call callWithVideo:call.isVideoCall];
                                                                       }
                                                                   }
                                                                   else
                                                                   {
                                                                       // Ignore the call
                                                                       [call hangupWithReason:reason];
                                                                   }
                                                               }];
                                                               
                                                               // Show this screen within a navigation controller
                                                               UINavigationController *usersDevicesNavigationController = [[RiotNavigationController alloc] init];
                                                               
                                                               // Set Riot navigation bar colors
                                                               [ThemeService.shared.theme applyStyleOnNavigationBar:usersDevicesNavigationController.navigationBar];
                                                               usersDevicesNavigationController.navigationBar.barTintColor = ThemeService.shared.theme.backgroundColor;

                                                               [usersDevicesNavigationController pushViewController:usersDevicesViewController animated:NO];
                                                               
                                                               [self presentViewController:usersDevicesNavigationController animated:YES completion:nil];
                                                               
                                                           }
                                                           
                                                       }]];
        
        
        [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:(call.isIncoming ? @"unknown_devices_answer_anyway":@"unknown_devices_call_anyway")]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               self->currentAlert = nil;
                                                               
                                                               // Acknowledge the existence of all devices
                                                               [self startActivityIndicator];
                                                               [self.mainSession.crypto setDevicesKnown:unknownDevices complete:^{
                                                                   
                                                                   [self stopActivityIndicator];
                                                                   
                                                                   // Retry the call
                                                                   if (call.isIncoming)
                                                                   {
                                                                       [call answer];
                                                                   }
                                                                   else
                                                                   {
                                                                       [call callWithVideo:call.isVideoCall];
                                                                   }
                                                               }];
                                                           }
                                                           
                                                       }]];
        
        [currentAlert mxk_setAccessibilityIdentifier:@"CallVCUnknownDevicesAlert"];
        [self presentViewController:currentAlert animated:YES completion:nil];
    }
    else
    {
        [super call:call didEncounterError:error reason:reason];
    }
}


#pragma mark - Fallback STUN server

- (void)checkStunServerFallbackWithCallState:(MXCallState)callState
{
    // Detect if we should display the prompt to fallback to the STUN server defined
    // in the app plist if the homeserver does not provide STUN or TURN servers.
    // We should display it if the call ends while we were in connecting state
    if (!self.mainSession.callManager.turnServers
        && !self.mainSession.callManager.fallbackSTUNServer
        && !RiotSettings.shared.isAllowStunServerFallbackHasBeenSetOnce)
    {
        switch (callState)
        {
            case MXCallStateConnecting:
                promptForStunServerFallback = YES;
                break;

            case MXCallStateConnected:
                promptForStunServerFallback = NO;
                break;

            case MXCallStateEnded:
                if (promptForStunServerFallback)
                {
                    _shouldPromptForStunServerFallback = YES;
                }

            default:
                // There is nothing to do for other states
                break;
        }
    }
}


#pragma mark - Properties

- (id<Theme>)overriddenTheme
{
    if (_overriddenTheme == nil)
    {
        _overriddenTheme = [DarkTheme new];
    }
    return _overriddenTheme;
}

- (void)setMxCall:(MXCall *)mxCall
{
    [super setMxCall:mxCall];
    
    if (self.videoMuteButton.isHidden)
    {
        //  shift more button to left
        self.moreButtonLeadingConstraint.constant = 8.0;
    }
}

- (UIImage*)picturePlaceholder
{
    CGFloat fontSize = floor(self.callerImageViewWidthConstraint.constant * 0.7);
    
    if (self.peer)
    {
        // Use the vector style placeholder
        return [AvatarGenerator generateAvatarForMatrixItem:self.peer.userId
                                            withDisplayName:self.peer.displayname
                                                       size:self.callerImageViewWidthConstraint.constant
                                                andFontSize:fontSize];
    }
    else if (self.mxCall.room)
    {
        return [AvatarGenerator generateAvatarForMatrixItem:self.mxCall.room.roomId
                                            withDisplayName:self.mxCall.room.summary.displayname
                                                       size:self.callerImageViewWidthConstraint.constant
                                                andFontSize:fontSize];
    }
    
    return [MXKTools paintImage:[UIImage imageNamed:@"placeholder"]
                      withColor:self.overriddenTheme.tintColor];
}

- (void)updatePeerInfoDisplay
{
    NSString *peerDisplayName;
    NSString *peerAvatarURL;
    
    if (self.peer)
    {
        peerDisplayName = [self.peer displayname];
        if (!peerDisplayName.length)
        {
            peerDisplayName = self.peer.userId;
        }
        peerAvatarURL = self.peer.avatarUrl;
    }
    else if (self.mxCall.isConferenceCall)
    {
        peerDisplayName = self.mxCall.room.summary.displayname;
        peerAvatarURL = self.mxCall.room.summary.avatar;
    }
    
    self.callerNameLabel.text = peerDisplayName;
    
    self.blurredCallerImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.callerImageView.contentMode = UIViewContentModeScaleAspectFill;
    if (peerAvatarURL)
    {
        // Retrieve the avatar in full resolution
        [self.blurredCallerImageView setImageURI:peerAvatarURL
                                        withType:nil
                             andImageOrientation:UIImageOrientationUp
                                    previewImage:self.picturePlaceholder
                                    mediaManager:self.mainSession.mediaManager];
        
        // Retrieve the avatar in full resolution
        [self.callerImageView setImageURI:peerAvatarURL
                                 withType:nil
                      andImageOrientation:UIImageOrientationUp
                             previewImage:self.picturePlaceholder
                             mediaManager:self.mainSession.mediaManager];
    }
    else
    {
        self.blurredCallerImageView.image = self.picturePlaceholder;
        self.callerImageView.image = self.picturePlaceholder;
    }
}

#pragma mark - Sounds

- (NSURL*)audioURLWithName:(NSString*)soundName
{
    NSURL *audioUrl;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:soundName ofType:@"mp3"];
    if (path)
    {
        audioUrl = [NSURL fileURLWithPath:path];
    }
    
    // Use by default the matrix kit sounds.
    if (!audioUrl)
    {
        audioUrl = [super audioURLWithName:soundName];
    }
    
    return audioUrl;
}

#pragma mark - Actions

- (IBAction)onButtonPressed:(id)sender
{
    if (sender == _chatButton)
    {
        if (self.delegate)
        {
            // Dismiss the view controller whereas the call is still running
            [self.delegate dismissCallViewController:self completion:^{
                
                if (self.mxCall.room)
                {
                    // Open the room page
                    [[AppDelegate theDelegate] showRoom:self.mxCall.room.roomId andEventId:nil withMatrixSession:self.mxCall.room.mxSession];
                }
                
            }];
        }
    }
    else
    {
        [super onButtonPressed:sender];
    }
}

- (void)setInPiP:(BOOL)inPiP
{
    _inPiP = inPiP;
    
    if (_inPiP)
    {
        self.overlayContainerView.hidden = YES;
        self.callerImageView.hidden = YES;
        self.callerNameLabel.hidden = YES;
        self.callStatusLabel.hidden = YES;
        self.localPreviewContainerView.hidden = YES;
        self.localPreviewActivityView.hidden = YES;
    }
    else
    {
        self.localPreviewContainerView.hidden = NO;
        self.callerImageView.hidden = NO;
        self.callerNameLabel.hidden = NO;
        self.callStatusLabel.hidden = NO;
        
        //  show controls when coming back from PiP mode
        [self showOverlayContainer:YES];
    }
}

- (void)showOverlayContainer:(BOOL)isShown
{
    if (self.inPiP)
    {
        return;
    }
    
    [super showOverlayContainer:isShown];
}

#pragma mark - DTMF

- (void)openDialpad
{
    DialpadConfiguration *config = [[DialpadConfiguration alloc] initWithShowsTitle:YES
                                                                   showsCloseButton:YES
                                                               showsBackspaceButton:NO
                                                                    showsCallButton:NO
                                                                  formattingEnabled:NO
                                                                     editingEnabled:NO];
    DialpadViewController *controller = [DialpadViewController instantiateWithConfiguration:config];
    controller.delegate = self;
    self.customSizedPresentationController = [[CustomSizedPresentationController alloc] initWithPresentedViewController:controller presentingViewController:self];
    self.customSizedPresentationController.dismissOnBackgroundTap = NO;
    self.customSizedPresentationController.cornerRadius = 16;
    
    controller.transitioningDelegate = self.customSizedPresentationController;
    [self presentViewController:controller animated:YES completion:nil];
}

#pragma mark - DialpadViewControllerDelegate

- (void)dialpadViewControllerDidTapClose:(DialpadViewController *)viewController
{
    [viewController dismissViewControllerAnimated:YES completion:nil];
    self.customSizedPresentationController = nil;
}

- (void)dialpadViewControllerDidTapDigit:(DialpadViewController *)viewController digit:(NSString *)digit
{
    BOOL result = [self.mxCall sendDTMF:digit
                               duration:0
                           interToneGap:0];
    
    NSLog(@"[CallViewController] Sending DTMF tones %@", result ? @"succeeded": @"failed");
}

#pragma mark - PictureInPicturable

- (void)enterPiP
{
    self.inPiP = YES;
}

- (void)exitPiP
{
    self.inPiP = NO;
}

@end
