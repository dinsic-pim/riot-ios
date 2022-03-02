/*
 Copyright 2015 OpenMarket Ltd
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

#import "RecentsViewController.h"

#import "MXRoom+Riot.h"

#import "RoomViewController.h"

#import "RageShakeManager.h"

#import "TableViewCellWithCollectionView.h"

#import "GeneratedInterface-Swift.h"

NSString *const RecentsViewControllerDataReadyNotification = @"RecentsViewControllerDataReadyNotification";

@interface RecentsViewController () </*CreateRoomCoordinatorBridgePresenterDelegate, RoomsDirectoryCoordinatorBridgePresenterDelegate,*/ RoomNotificationSettingsCoordinatorBridgePresenterDelegate>
{
    // Tell whether a recents refresh is pending (suspended during editing mode).
    BOOL isRefreshPending;
    
    // Observe UIApplicationDidEnterBackgroundNotification to cancel editing mode when app leaves the foreground state.
    __weak id UIApplicationDidEnterBackgroundNotificationObserver;
    
    // Observe kAppDelegateDidTapStatusBarNotification to handle tap on clock status bar.
    __weak id kAppDelegateDidTapStatusBarNotificationObserver;
    
    // Observe kMXNotificationCenterDidUpdateRules to update missed messages counts.
    __weak id kMXNotificationCenterDidUpdateRulesObserver;
    
    MXHTTPOperation *currentRequest;
    
    // Observe kThemeServiceDidChangeThemeNotification to handle user interface theme change.
    __weak id kThemeServiceDidChangeThemeNotificationObserver;
}

//@property (nonatomic, strong) CreateRoomCoordinatorBridgePresenter *createRoomCoordinatorBridgePresenter;
//
//@property (nonatomic, strong) RoomsDirectoryCoordinatorBridgePresenter *roomsDirectoryCoordinatorBridgePresenter;
//
//@property (nonatomic, strong) ExploreRoomCoordinatorBridgePresenter *exploreRoomsCoordinatorBridgePresenter;

//@property (nonatomic, strong) SpaceFeatureUnavailablePresenter *spaceFeatureUnavailablePresenter;

//@property (nonatomic, strong) CustomSizedPresentationController *customSizedPresentationController;

@property (nonatomic, strong) RoomNotificationSettingsCoordinatorBridgePresenter *roomNotificationSettingsCoordinatorBridgePresenter;

@end

@implementation RecentsViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([RecentsViewController class])
                          bundle:[NSBundle bundleForClass:[RecentsViewController class]]];
}

+ (instancetype)recentListViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([RecentsViewController class])
                                          bundle:[NSBundle bundleForClass:[RecentsViewController class]]];
}

#pragma mark -

- (void)finalizeInit
{
    [super finalizeInit];
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];
    
    // Remove the search option from the navigation bar.
    self.enableBarButtonSearch = NO;
    
    _enableDragging = NO;
    
    _enableStickyHeaders = NO;
    _stickyHeaderHeight = 30.0;
    
    displayedSectionHeaders = [NSMutableArray array];
    
    // Set itself as delegate by default.
    self.delegate = self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.recentsTableView.accessibilityIdentifier = @"RecentsVCTableView";
    
    // Register here the customized cell view class used to render recents
    [self.recentsTableView registerNib:RoomsDiscussionCell.nib forCellReuseIdentifier:RoomsDiscussionCell.defaultReuseIdentifier];
    [self.recentsTableView registerNib:RoomsRoomCell.nib forCellReuseIdentifier:RoomsRoomCell.defaultReuseIdentifier];
    [self.recentsTableView registerNib:RoomsInviteCell.nib forCellReuseIdentifier:RoomsInviteCell.defaultReuseIdentifier];
    [self.recentsTableView registerNib:RoomsTchapInfoCell.nib forCellReuseIdentifier:RoomsTchapInfoCell.defaultReuseIdentifier];
    
    // Register key backup banner cells
    [self.recentsTableView registerNib:SecureBackupBannerCell.nib forCellReuseIdentifier:SecureBackupBannerCell.defaultReuseIdentifier];

    // Register key verification banner cells
    [self.recentsTableView registerNib:CrossSigningSetupBannerCell.nib forCellReuseIdentifier:CrossSigningSetupBannerCell.defaultReuseIdentifier];
    
    // Hide line separators of empty cells
    self.recentsTableView.tableFooterView = [[UIView alloc] init];
    
    // Apply dragging settings
    self.enableDragging = _enableDragging;
    
    MXWeakify(self);
    
    // Observe UIApplicationDidEnterBackgroundNotification to refresh bubbles when app leaves the foreground state.
    UIApplicationDidEnterBackgroundNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        // Leave potential editing mode
        [self cancelEditionMode:self->isRefreshPending];
        
    }];
    
    // Observe user interface theme change.
    kThemeServiceDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kThemeServiceDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        [self userInterfaceThemeDidChange];
        
    }];
    [self userInterfaceThemeDidChange];
}

- (void)userInterfaceThemeDidChange
{
    [ThemeService.shared.theme applyStyleOnNavigationBar:self.navigationController.navigationBar];

    self.activityIndicator.backgroundColor = ThemeService.shared.theme.overlayBackgroundColor;
    
    // Use the primary bg color for the recents table view in plain style.
    self.recentsTableView.backgroundColor = ThemeService.shared.theme.backgroundColor;
    topview.backgroundColor = ThemeService.shared.theme.headerBackgroundColor;
    self.view.backgroundColor = ThemeService.shared.theme.backgroundColor;
    
    if (self.recentsSearchBar)
    {
        [ThemeService.shared.theme applyStyleOnSearchBar:self.recentsSearchBar];
    }
    
    if (self.recentsTableView.dataSource)
    {
        // Force table refresh
        [self cancelEditionMode:YES];
    }
    
//    [self.emptyView updateWithTheme:ThemeService.shared.theme];

    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return ThemeService.shared.theme.statusBarStyle;
}

- (void)destroy
{
    [super destroy];
    
    if (currentRequest)
    {
        [currentRequest cancel];
        currentRequest = nil;
    }
    
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    if (UIApplicationDidEnterBackgroundNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:UIApplicationDidEnterBackgroundNotificationObserver];
        UIApplicationDidEnterBackgroundNotificationObserver = nil;
    }
    
    if (kThemeServiceDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kThemeServiceDidChangeThemeNotificationObserver];
        kThemeServiceDidChangeThemeNotificationObserver = nil;
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    
    self.recentsTableView.editing = editing;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Reset back user interactions
    self.userInteractionEnabled = YES;
    
    // Deselect the current selected row, it will be restored on viewDidAppear (if any)
    NSIndexPath *indexPath = [self.recentsTableView indexPathForSelectedRow];
    if (indexPath)
    {
        [self.recentsTableView deselectRowAtIndexPath:indexPath animated:NO];
    }
    
    MXWeakify(self);
    
    // Observe kAppDelegateDidTapStatusBarNotificationObserver.
    kAppDelegateDidTapStatusBarNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kAppDelegateDidTapStatusBarNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        [self scrollToTop:YES];
        
    }];
    
    // Observe kMXNotificationCenterDidUpdateRules to refresh missed messages counts
    kMXNotificationCenterDidUpdateRulesObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXNotificationCenterDidUpdateRules object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        
        MXStrongifyAndReturnIfNil(self);
        
        [self refreshRecentsTable];
        
    }];
    
    // Apply the current theme
    [self userInterfaceThemeDidChange];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Leave potential editing mode
    [self cancelEditionMode:NO];
    
    if (kAppDelegateDidTapStatusBarNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kAppDelegateDidTapStatusBarNotificationObserver];
        kAppDelegateDidTapStatusBarNotificationObserver = nil;
    }
    
    if (kMXNotificationCenterDidUpdateRulesObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kMXNotificationCenterDidUpdateRulesObserver];
        kMXNotificationCenterDidUpdateRulesObserver = nil;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Release the current selected item (if any) except if the second view controller is still visible.
//    if (self.splitViewController.isCollapsed)
//    {
//        // Release the current selected room (if any).
//        [[AppDelegate theDelegate].masterTabBarController releaseSelectedItem];
//    }
//    else
//    {
        // In case of split view controller where the primary and secondary view controllers are displayed side-by-side onscreen,
        // the selected room (if any) is highlighted.
        [self refreshCurrentSelectedCell:YES];
//    }
    
    [self.screenTimer start];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.screenTimer stop];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self refreshStickyHeadersContainersHeight];
        
    });
}

#pragma mark - Override MXKRecentListViewController

- (void)refreshRecentsTable
{
    // Refresh the tabBar icon badges
//    [[AppDelegate theDelegate].masterTabBarController refreshTabBarBadges];
    
    // do not refresh if there is a pending recent drag and drop
//    if (movingCellPath)
//    {
//        return;
//    }
    
    isRefreshPending = NO;
    
    if (editedRoomId)
    {
        // Check whether the user didn't leave the room
        MXRoom *room = [self.mainSession roomWithRoomId:editedRoomId];
        if (room)
        {
            isRefreshPending = YES;
            return;
        }
        else
        {
            // Cancel the editing mode, a new refresh will be triggered.
            [self cancelEditionMode:YES];
            return;
        }
    }
    
    // Force reset existing sticky headers if any
    [self resetStickyHeaders];
    
    [self.recentsTableView reloadData];
    
    if (_shouldScrollToTopOnRefresh)
    {
        [self scrollToTop:NO];
        _shouldScrollToTopOnRefresh = NO;
    }
    
    [self prepareStickyHeaders];
    
    // In case of split view controller where the primary and secondary view controllers are displayed side-by-side on screen,
    // the selected room (if any) is updated.
    if (!self.splitViewController.isCollapsed)
    {
        [self refreshCurrentSelectedCell:NO];
    }
}

#pragma mark -

- (void)refreshCurrentSelectedCell:(BOOL)forceVisible
{
    // Update here the index of the current selected cell (if any) - Useful in landscape mode with split view controller.
//    NSIndexPath *currentSelectedCellIndexPath = nil;
//    MasterTabBarController *masterTabBarController = [AppDelegate theDelegate].masterTabBarController;
//    if (masterTabBarController.selectedRoomId)
//    {
//        // Look for the rank of this selected room in displayed recents
//        currentSelectedCellIndexPath = [self.dataSource cellIndexPathWithRoomId:masterTabBarController.selectedRoomId andMatrixSession:masterTabBarController.selectedRoomSession];
//    }
//
//    if (currentSelectedCellIndexPath)
//    {
//        // Select the right row
//        [self.recentsTableView selectRowAtIndexPath:currentSelectedCellIndexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
//
//        if (forceVisible)
//        {
//            // Scroll table view to make the selected row appear at second position
//            NSInteger topCellIndexPathRow = currentSelectedCellIndexPath.row ? currentSelectedCellIndexPath.row - 1: currentSelectedCellIndexPath.row;
//            NSIndexPath* indexPath = [NSIndexPath indexPathForRow:topCellIndexPathRow inSection:currentSelectedCellIndexPath.section];
//            if ([self.recentsTableView vc_hasIndexPath:indexPath])
//            {
//                [self.recentsTableView scrollToRowAtIndexPath:indexPath
//                                             atScrollPosition:UITableViewScrollPositionTop
//                                                     animated:NO];
//            }
//        }
//    }
//    else
//    {
        NSIndexPath *indexPath = [self.recentsTableView indexPathForSelectedRow];
        if (indexPath)
        {
            [self.recentsTableView deselectRowAtIndexPath:indexPath animated:NO];
        }
//    }
}

- (void)cancelEditionMode:(BOOL)forceRefresh
{
    if (self.recentsTableView.isEditing || self.isEditing)
    {
        // Leave editing mode first
        isRefreshPending = forceRefresh;
        [self setEditing:NO];
    }
    else
    {
        // Clean
        editedRoomId = nil;
        
        if (forceRefresh)
        {
            [self refreshRecentsTable];
        }
    }
}

- (void)cancelEditionModeAndForceTableViewRefreshIfNeeded
{
    [self cancelEditionMode:isRefreshPending];
}

#pragma mark - Sticky Headers

- (void)setEnableStickyHeaders:(BOOL)enableStickyHeaders
{
    _enableStickyHeaders = enableStickyHeaders;
    
    // Refresh the table display if it is already rendered.
    if (self.recentsTableView.contentSize.height)
    {
        [self refreshRecentsTable];
    }
}

- (void)setStickyHeaderHeight:(CGFloat)stickyHeaderHeight
{
    if (_stickyHeaderHeight != stickyHeaderHeight)
    {
        _stickyHeaderHeight = stickyHeaderHeight;
        
        // Force a sticky headers refresh
        self.enableStickyHeaders = _enableStickyHeaders;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForStickyHeaderInSection:(NSInteger)section
{
    // Return the section header by default.
    return [self tableView:tableView viewForHeaderInSection:section];
}

- (void)resetStickyHeaders
{
    // Release sticky header
    _stickyHeadersTopContainerHeightConstraint.constant = 0;
    _stickyHeadersBottomContainerHeightConstraint.constant = 0;
    
    for (UIView *view in _stickyHeadersTopContainer.subviews)
    {
        [view removeFromSuperview];
    }
    for (UIView *view in _stickyHeadersBottomContainer.subviews)
    {
        [view removeFromSuperview];
    }
    
    [displayedSectionHeaders removeAllObjects];
    
    self.recentsTableView.contentInset = UIEdgeInsetsZero;
}

- (void)prepareStickyHeaders
{
    // We suppose here [resetStickyHeaders] has been already called if need.
    
    NSInteger sectionsCount = self.recentsTableView.numberOfSections;
    
    if (self.enableStickyHeaders && sectionsCount)
    {
        NSUInteger topContainerOffset = 0;
        NSUInteger bottomContainerOffset = 0;
        CGRect frame;
        
        UIView *stickyHeader = [self viewForStickyHeaderInSection:0 withSwipeGestureRecognizerInDirection:UISwipeGestureRecognizerDirectionDown];
        frame = stickyHeader.frame;
        frame.origin.y = topContainerOffset;
        stickyHeader.frame = frame;
        [self.stickyHeadersTopContainer addSubview:stickyHeader];
        topContainerOffset = stickyHeader.frame.size.height;
        
        for (NSUInteger index = 1; index < sectionsCount; index++)
        {
            stickyHeader = [self viewForStickyHeaderInSection:index withSwipeGestureRecognizerInDirection:UISwipeGestureRecognizerDirectionDown];
            frame = stickyHeader.frame;
            frame.origin.y = topContainerOffset;
            stickyHeader.frame = frame;
            [self.stickyHeadersTopContainer addSubview:stickyHeader];
            topContainerOffset += frame.size.height;
            
            stickyHeader = [self viewForStickyHeaderInSection:index withSwipeGestureRecognizerInDirection:UISwipeGestureRecognizerDirectionUp];
            frame = stickyHeader.frame;
            frame.origin.y = bottomContainerOffset;
            stickyHeader.frame = frame;
            [self.stickyHeadersBottomContainer addSubview:stickyHeader];
            bottomContainerOffset += frame.size.height;
        }
        
        [self refreshStickyHeadersContainersHeight];
    }
}

- (UIView *)viewForStickyHeaderInSection:(NSInteger)section withSwipeGestureRecognizerInDirection:(UISwipeGestureRecognizerDirection)swipeDirection
{
    UIView *stickyHeader = [self tableView:self.recentsTableView viewForStickyHeaderInSection:section];
    stickyHeader.tag = section;
    stickyHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // Remove existing gesture recognizers
    while (stickyHeader.gestureRecognizers.count)
    {
        UIGestureRecognizer *gestureRecognizer = stickyHeader.gestureRecognizers.lastObject;
        [stickyHeader removeGestureRecognizer:gestureRecognizer];
    }
    
    // Handle tap gesture, the section is moved up on the tap.
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapOnSectionHeader:)];
    [tap setNumberOfTouchesRequired:1];
    [tap setNumberOfTapsRequired:1];
    [stickyHeader addGestureRecognizer:tap];
    
    // Handle vertical swipe gesture with the provided direction, by default the section will be moved up on this swipe.
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeOnSectionHeader:)];
    [swipe setNumberOfTouchesRequired:1];
    [swipe setDirection:swipeDirection];
    [stickyHeader addGestureRecognizer:swipe];
    
    return stickyHeader;
}

- (void)didTapOnSectionHeader:(UIGestureRecognizer*)gestureRecognizer
{
    UIView *view = gestureRecognizer.view;
    NSInteger section = view.tag;
    
    // Scroll to the top of this section
    if ([self.recentsTableView numberOfRowsInSection:section] > 0)
    {
        [self.recentsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section] atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}

- (void)didSwipeOnSectionHeader:(UISwipeGestureRecognizer*)gestureRecognizer
{
    UIView *view = gestureRecognizer.view;
    NSInteger section = view.tag;
    
    if ([self.recentsTableView numberOfRowsInSection:section] > 0)
    {
        // Check whether the first cell of this section is already visible.
        UITableViewCell *firstSectionCell = [self.recentsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section]];
        if (firstSectionCell)
        {
            // Scroll to the top of the previous section (if any)
            if (section && [self.recentsTableView numberOfRowsInSection:(section - 1)] > 0)
            {
                [self.recentsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:(section - 1)] atScrollPosition:UITableViewScrollPositionTop animated:YES];
            }
        }
        else
        {
            // Scroll to the top of this section
            [self.recentsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section] atScrollPosition:UITableViewScrollPositionTop animated:YES];
        }
    }
}

- (void)refreshStickyHeadersContainersHeight
{
    if (_enableStickyHeaders)
    {
        NSUInteger lowestSectionInBottomStickyHeader = NSNotFound;
        CGFloat containerHeight;
        
        // Retrieve the first header actually visible in the recents table view.
        // Caution: In some cases like the screen rotation, some displayed section headers are temporarily not visible.
        UIView *firstDisplayedSectionHeader;
        for (UIView *header in displayedSectionHeaders)
        {
            if (header.frame.origin.y + header.frame.size.height > self.recentsTableView.contentOffset.y)
            {
                firstDisplayedSectionHeader = header;
                break;
            }
        }
        
        if (firstDisplayedSectionHeader)
        {
            // Initialize the top container height by considering the headers which are before the first visible section header.
            containerHeight = 0;
            for (UIView *header in _stickyHeadersTopContainer.subviews)
            {
                if (header.tag < firstDisplayedSectionHeader.tag)
                {
                    containerHeight += self.stickyHeaderHeight;
                }
            }
            
            // Check whether the first visible section header is partially hidden.
            if (firstDisplayedSectionHeader.frame.origin.y < self.recentsTableView.contentOffset.y)
            {
                // Compute the height of the hidden part.
                CGFloat delta = self.recentsTableView.contentOffset.y - firstDisplayedSectionHeader.frame.origin.y;
                
                if (delta < self.stickyHeaderHeight)
                {
                    containerHeight += delta;
                }
                else
                {
                    containerHeight += self.stickyHeaderHeight;
                }
            }
            
            if (containerHeight)
            {
                self.stickyHeadersTopContainerHeightConstraint.constant = containerHeight;
                self.recentsTableView.contentInset = UIEdgeInsetsMake(-self.stickyHeaderHeight, 0, 0, 0);
            }
            else
            {
                self.stickyHeadersTopContainerHeightConstraint.constant = 0;
                self.recentsTableView.contentInset = UIEdgeInsetsZero;
            }
            
            // Look for the lowest section index visible in the bottom sticky headers.
            CGFloat maxVisiblePosY = self.recentsTableView.contentOffset.y + self.recentsTableView.frame.size.height - self.recentsTableView.adjustedContentInset.bottom;
            UIView *lastDisplayedSectionHeader = displayedSectionHeaders.lastObject;
            
            for (UIView *header in _stickyHeadersBottomContainer.subviews)
            {
                if (header.tag > lastDisplayedSectionHeader.tag)
                {
                    maxVisiblePosY -= self.stickyHeaderHeight;
                }
            }
            
            for (NSInteger index = displayedSectionHeaders.count; index > 0;)
            {
                lastDisplayedSectionHeader = displayedSectionHeaders[--index];
                if (lastDisplayedSectionHeader.frame.origin.y + self.stickyHeaderHeight > maxVisiblePosY)
                {
                    maxVisiblePosY -= self.stickyHeaderHeight;
                }
                else
                {
                    lowestSectionInBottomStickyHeader = lastDisplayedSectionHeader.tag + 1;
                    break;
                }
            }
        }
        else
        {
            // Handle here the case where no section header is currently displayed in the table.
            // No more than one section is then displayed, we retrieve this section by checking the first visible cell.
            NSIndexPath *firstCellIndexPath = [self.recentsTableView indexPathForRowAtPoint:CGPointMake(0, self.recentsTableView.contentOffset.y)];
            if (firstCellIndexPath)
            {
                NSInteger section = firstCellIndexPath.section;
                
                // Refresh top container of the sticky headers
                CGFloat containerHeight = 0;
                for (UIView *header in _stickyHeadersTopContainer.subviews)
                {
                    if (header.tag <= section)
                    {
                        containerHeight += header.frame.size.height;
                    }
                }
                
                self.stickyHeadersTopContainerHeightConstraint.constant = containerHeight;
                if (containerHeight)
                {
                    self.recentsTableView.contentInset = UIEdgeInsetsMake(-self.stickyHeaderHeight, 0, 0, 0);
                }
                else
                {
                    self.recentsTableView.contentInset = UIEdgeInsetsZero;
                }
                
                // Set the lowest section index visible in the bottom sticky headers.
                lowestSectionInBottomStickyHeader = section + 1;
            }
        }
        
        // Update here the height of the bottom container of the sticky headers thanks to lowestSectionInBottomStickyHeader.
        containerHeight = 0;
        CGRect bounds = _stickyHeadersBottomContainer.frame;
        bounds.origin.y = 0;
        
        for (UIView *header in _stickyHeadersBottomContainer.subviews)
        {
            if (header.tag > lowestSectionInBottomStickyHeader)
            {
                containerHeight += self.stickyHeaderHeight;
            }
            else if (header.tag == lowestSectionInBottomStickyHeader)
            {
                containerHeight += self.stickyHeaderHeight;
                bounds.origin.y = header.frame.origin.y;
            }
        }
        
        if (self.stickyHeadersBottomContainerHeightConstraint.constant != containerHeight)
        {
            self.stickyHeadersBottomContainerHeightConstraint.constant = containerHeight;
            self.stickyHeadersBottomContainer.bounds = bounds;
        }
    }
}

#pragma mark - Internal methods

// Disable UI interactions in this screen while we are going to open another screen.
// Interactions on reset on viewWillAppear.
- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled
{
    self.view.userInteractionEnabled = userInteractionEnabled;
}

//- (RecentsDataSource*)recentsDataSource
//{
//    RecentsDataSource* recentsDataSource = nil;
//
//    if ([self.dataSource isKindOfClass:[RecentsDataSource class]])
//    {
//        recentsDataSource = (RecentsDataSource*)self.dataSource;
//    }
//
//    return recentsDataSource;
//}

- (void)showSpaceInviteNotAvailable
{
//    if (!self.spaceFeatureUnavailablePresenter)
//    {
//        self.spaceFeatureUnavailablePresenter = [SpaceFeatureUnavailablePresenter new];
//    }
//    
//    [self.spaceFeatureUnavailablePresenter presentUnavailableFeatureFrom:self animated:YES];
}

#pragma mark - MXKDataSourceDelegate

- (Class<MXKCellRendering>)cellViewClassForCellData:(MXKCellData*)cellData
{
    id<MXKRecentCellDataStoring> cellDataStoring = (id<MXKRecentCellDataStoring> )cellData;
    
    if ([cellDataStoring.roomSummary isKindOfClass:[MXRoomSummary class]] &&
         ((MXRoomSummary *)cellDataStoring.roomSummary).room.summary.membership == MXMembershipInvite)    {
        return RoomsInviteCell.class;
    }
    else if ([cellDataStoring.roomSummary isKindOfClass:[MXRoomSummary class]] &&
             ((MXRoomSummary *)cellDataStoring.roomSummary).tc_isServerNotice)
    {
        return RoomsTchapInfoCell.class;
    }
    else if (cellDataStoring.roomSummary.isDirect)
    {
        return RoomsDiscussionCell.class;
    }
    else
    {
        return RoomsRoomCell.class;
    }
}

- (NSString *)cellReuseIdentifierForCellData:(MXKCellData*)cellData
{
    Class class = [self cellViewClassForCellData:cellData];
    
    if ([class respondsToSelector:@selector(defaultReuseIdentifier)])
    {
        return [class defaultReuseIdentifier];
    }
    
    return nil;
}

- (void)dataSource:(MXKDataSource *)dataSource didRecognizeAction:(NSString *)actionIdentifier inCell:(id<MXKCellRendering>)cell userInfo:(NSDictionary *)userInfo
{
//    // Handle here user actions on recents for Riot app
//    if ([actionIdentifier isEqualToString:kInviteRecentTableViewCellPreviewButtonPressed])
//    {
//        // Retrieve the invited room
//        MXRoom *invitedRoom = userInfo[kInviteRecentTableViewCellRoomKey];
//
//        if (invitedRoom.summary.roomType == MXRoomTypeSpace)
//        {
//            // Indicates that spaces are not supported
//            [self showSpaceInviteNotAvailable];
//            return;
//        }
//
//        // Display the room preview
//        [self showRoomWithRoomId:invitedRoom.roomId inMatrixSession:invitedRoom.mxSession];
//    }
//    else if ([actionIdentifier isEqualToString:kInviteRecentTableViewCellAcceptButtonPressed])
//    {
//        // Retrieve the invited room
//        MXRoom *invitedRoom = userInfo[kInviteRecentTableViewCellRoomKey];
//
//        if (invitedRoom.summary.roomType == MXRoomTypeSpace)
//        {
//            // Indicates that spaces are not supported
//            [self showSpaceInviteNotAvailable];
//            return;
//        }
//
//        // Accept invitation
//        [self joinRoom:invitedRoom completion:nil];
//    }
//    else if ([actionIdentifier isEqualToString:kInviteRecentTableViewCellDeclineButtonPressed])
//    {
//        // Retrieve the invited room
//        MXRoom *invitedRoom = userInfo[kInviteRecentTableViewCellRoomKey];
//
//        [self cancelEditionMode:isRefreshPending];
//
//        // Decline the invitation
//        [self leaveRoom:invitedRoom completion:nil];
//    }
//    else
//    {
        // Keep default implementation for other actions if any
        if ([super respondsToSelector:@selector(cell:didRecognizeAction:userInfo:)])
        {
            [super dataSource:dataSource didRecognizeAction:actionIdentifier inCell:cell userInfo:userInfo];
        }
//    }
}

- (void)dataSource:(MXKDataSource *)dataSource didCellChange:(id)changes
{
    BOOL cellReloaded = NO;
    if ([changes isKindOfClass:NSNumber.class])
    {
        NSInteger section = ((NSNumber *)changes).integerValue;
        if (section >= 0)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:section];
            UITableViewCell *cell = [self.recentsTableView cellForRowAtIndexPath:indexPath];
            if ([cell isKindOfClass:TableViewCellWithCollectionView.class])
            {
                TableViewCellWithCollectionView *collectionViewCell = (TableViewCellWithCollectionView *)cell;
                [collectionViewCell.collectionView reloadData];
                cellReloaded = YES;
            }
        }
    }
    
    if (!cellReloaded)
    {
        [super dataSource:dataSource didCellChange:changes];
    }
    else
    {
        // Since we've enabled room list pagination, `refreshRecentsTable` not called in this case.
        // Refresh tab bar badges separately.
//        [[AppDelegate theDelegate].masterTabBarController refreshTabBarBadges];
    }
    
    if (changes == nil)
    {
        [self showEmptyViewIfNeeded];
    }
    
    if (dataSource.state == MXKDataSourceStateReady)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:RecentsViewControllerDataReadyNotification
                                                            object:self];
    }
}

#pragma mark - Swipe actions

- (void)tableView:(UITableView*)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self cancelEditionMode:isRefreshPending];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (nullable UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MXRoom *room = [self.dataSource getRoomAtIndexPath:indexPath];
    
    if (!room)
    {
        return nil;
    }
    
    // Display no action for the invited room
    if (room.summary.membership == MXMembershipInvite)
    {
        return nil;
    }
    
    // Store the identifier of the room related to the edited cell.
    editedRoomId = room.roomId;
    
    UIColor *selectedColor = ThemeService.shared.theme.tintColor;
    UIColor *unselectedColor = ThemeService.shared.theme.tabBarUnselectedItemTintColor;
    UIColor *actionBackgroundColor = ThemeService.shared.theme.baseColor;
    
    NSString* title = @"      ";
    
    // Notification toggle
    
    BOOL isMuted = room.isMute || room.isMentionsOnly;
    
    UIContextualAction *muteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:title
                                                                           handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        
        if ([BuildSettings showNotificationsV2])
        {
            [self changeEditedRoomNotificationSettings];
        }
        else
        {
            [self muteEditedRoomNotifications:!isMuted];
        }
        
        
        completionHandler(YES);
    }];
    muteAction.backgroundColor = actionBackgroundColor;
    
    UIImage *notificationImage = isMuted ? [UIImage imageNamed:@"notificationsOff"] : [UIImage imageNamed:@"notifications"];
    muteAction.image = [notificationImage vc_notRenderedImage];
    
    // Favorites management
    
    MXRoomTag* currentTag = nil;
    
    // Get the room tag (use only the first one).
    if (room.accountData.tags)
    {
        NSArray<MXRoomTag*>* tags = room.accountData.tags.allValues;
        if (tags.count)
        {
            currentTag = tags[0];
        }
    }
    
    BOOL isFavourite = (currentTag && [kMXRoomTagFavourite isEqualToString:currentTag.name]);
    
    UIContextualAction *favouriteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:title
                                                                           handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        NSString *favouriteTag = isFavourite ? nil : kMXRoomTagFavourite;
        [self updateEditedRoomTag:favouriteTag];
        completionHandler(YES);
    }];
    favouriteAction.backgroundColor = actionBackgroundColor;
    
    UIImage *favouriteImage = isFavourite ? [UIImage imageNamed:@"pin"] : [UIImage imageNamed:@"unpin"];
    favouriteAction.image = [favouriteImage vc_notRenderedImage];
    
    // Leave action
    
    UIContextualAction *leaveAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                                   title:title
                                                                                 handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self leaveEditedRoom];
        completionHandler(YES);
    }];
    leaveAction.backgroundColor = actionBackgroundColor;
    
    UIImage *leaveImage = [UIImage imageNamed:@"leave"];
    leaveImage = [leaveImage vc_tintedImageUsingColor:selectedColor];
    leaveAction.image = [leaveImage vc_notRenderedImage];
        
    // Create swipe action configuration
    
    NSArray<UIContextualAction*> *actions = @[
        leaveAction,
        favouriteAction,
        muteAction
    ];
    
    UISwipeActionsConfiguration *swipeActionConfiguration = [UISwipeActionsConfiguration configurationWithActions:actions];
    swipeActionConfiguration.performsFirstActionWithFullSwipe = NO;
    return swipeActionConfiguration;
}

- (void)leaveEditedRoom
{
    if (editedRoomId)
    {
        MXRoom *room = [self.mainSession roomWithRoomId:editedRoomId];
        if (!room)
        {
            return;
        }
        
        NSString *currentRoomId = editedRoomId;
        
        [self startActivityIndicator];
        MXWeakify(self);
        
        [room tc_isCurrentUserLastAdministrator:^(BOOL isLastAdmin) {
            MXStrongifyAndReturnIfNil(self);
            [self stopActivityIndicator];
            
            // confirm leave
            NSString *promptMessage = [VectorL10n roomParticipantsLeavePromptMsg];
            if (isLastAdmin)
            {
                promptMessage = NSLocalizedStringFromTable(@"tchap_room_admin_leave_prompt_msg", @"Tchap", nil);
            }
            
            MXWeakify(self);
            self->currentAlert = [UIAlertController alertControllerWithTitle:[VectorL10n roomParticipantsLeavePromptTitle]
                                                                     message:promptMessage
                                                              preferredStyle:UIAlertControllerStyleAlert];
            
            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[MatrixKitL10n cancel]
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction * action) {
                                                                     
                                                                     MXStrongifyAndReturnIfNil(self);
                                                                     self->currentAlert = nil;
                                                                     
                                                                 }]];
            
            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n leave]
                                                                   style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                                       
                                                                       MXStrongifyAndReturnIfNil(self);
                                                                       self->currentAlert = nil;
                                                                       
                                                                       // Check whether the user didn't leave the room yet
                                                                       // TODO: Handle multi-account
                                                                       MXRoom *room = [self.mainSession roomWithRoomId:currentRoomId];
                                                                       if (room)
                                                                       {
                                                                           [self startActivityIndicator];
                                                                           
                                                                           // cancel pending uploads/downloads
                                                                           // they are useless by now
                                                                           [MXMediaManager cancelDownloadsInCacheFolder:room.roomId];
                                                                           
                                                                           // TODO GFO cancel pending uploads related to this room
                                                                           
                                                                           NSLog(@"[RecentsViewController] Leave room (%@)", room.roomId);
                                                                           
                                                                           MXWeakify(self);
                                                                           [room leave:^{
                                                                               
                                                                               MXStrongifyAndReturnIfNil(self);
                                                                               [self stopActivityIndicator];
                                                                               // Force table refresh
                                                                               [self cancelEditionMode:YES];
                                                                               
                                                                           } failure:^(NSError *error) {
                                                                               
                                                                               NSLog(@"[RecentsViewController] Failed to leave room");
                                                                               MXStrongifyAndReturnIfNil(self);
                                                                               // Notify the end user
                                                                               NSString *userId = room.mxSession.myUser.userId;
                                                                               [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification
                                                                                                                                   object:error
                                                                                                                                 userInfo:userId ? @{kMXKErrorUserIdKey: userId} : nil];
                                                                               
                                                                               [self stopActivityIndicator];
                                                                               
                                                                               // Leave editing mode
                                                                               [self cancelEditionMode:self->isRefreshPending];
                                                                               
                                                                           }];
                                                                       }
                                                                       else
                                                                       {
                                                                           // Leave editing mode
                                                                           [self cancelEditionMode:self->isRefreshPending];
                                                                       }
                                                                       
                                                                   }]];
            
            [self->currentAlert mxk_setAccessibilityIdentifier:@"LeaveEditedRoomAlert"];
            [self presentViewController:self->currentAlert animated:YES completion:nil];
        }];
    }
}

- (void)updateEditedRoomTag:(NSString*)tag
{
    if (editedRoomId)
    {
        // Check whether the user didn't leave the room
        MXRoom *room = [self.mainSession roomWithRoomId:editedRoomId];
        if (room)
        {
            [self startActivityIndicator];
            
            [room setRoomTag:tag completion:^{
                
                [self stopActivityIndicator];
                
                // Force table refresh
                [self cancelEditionMode:YES];
                
            }];
        }
        else
        {
            // Leave editing mode
            [self cancelEditionMode:isRefreshPending];
        }
    }
}

- (void)changeEditedRoomNotificationSettings
{
    if (editedRoomId)
    {
        // Check whether the user didn't leave the room
        MXRoom *room = [self.mainSession roomWithRoomId:editedRoomId];
        if (room)
        {
           // navigate
            self.roomNotificationSettingsCoordinatorBridgePresenter = [[RoomNotificationSettingsCoordinatorBridgePresenter alloc] initWithRoom:room];
            self.roomNotificationSettingsCoordinatorBridgePresenter.delegate = self;
            [self.roomNotificationSettingsCoordinatorBridgePresenter presentFrom:self animated:YES];
        }
        [self cancelEditionMode:isRefreshPending];
    }
}

- (void)muteEditedRoomNotifications:(BOOL)mute
{
    if (editedRoomId)
    {
        // Check whether the user didn't leave the room
        MXRoom *room = [self.mainSession roomWithRoomId:editedRoomId];
        if (room)
        {
            [self startActivityIndicator];

            if (mute)
            {
                [room mentionsOnly:^{

                    [self stopActivityIndicator];

                    // Leave editing mode
                    [self cancelEditionMode:self->isRefreshPending];

                }];
            }
            else
            {
                [room allMessages:^{

                    [self stopActivityIndicator];

                    // Leave editing mode
                    [self cancelEditionMode:self->isRefreshPending];

                }];
            }
        }
        else
        {
            // Leave editing mode
            [self cancelEditionMode:isRefreshPending];
        }
    }
}

#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    cell.backgroundColor = ThemeService.shared.theme.backgroundColor;
    
    // Update the selected background view
    if (ThemeService.shared.theme.selectedBackgroundColor)
    {
        cell.selectedBackgroundView = [[UIView alloc] init];
        cell.selectedBackgroundView.backgroundColor = ThemeService.shared.theme.selectedBackgroundColor;
    }
    else
    {
        if (tableView.style == UITableViewStylePlain)
        {
            cell.selectedBackgroundView = nil;
        }
        else
        {
            cell.selectedBackgroundView.backgroundColor = nil;
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 30.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *sectionHeader = [super tableView:tableView viewForHeaderInSection:section];
    sectionHeader.tag = section;
    
    while (sectionHeader.gestureRecognizers.count)
    {
        UIGestureRecognizer *gestureRecognizer = sectionHeader.gestureRecognizers.lastObject;
        [sectionHeader removeGestureRecognizer:gestureRecognizer];
    }
    
    // Handle tap gesture
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapOnSectionHeader:)];
    [tap setNumberOfTouchesRequired:1];
    [tap setNumberOfTapsRequired:1];
    [sectionHeader addGestureRecognizer:tap];
    
    return sectionHeader;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if (_enableStickyHeaders)
    {
        view.tag = section;
        
        UIView *firstDisplayedSectionHeader = displayedSectionHeaders.firstObject;
        
        if (!firstDisplayedSectionHeader || section < firstDisplayedSectionHeader.tag)
        {
            [displayedSectionHeaders insertObject:view atIndex:0];
        }
        else
        {
            [displayedSectionHeaders addObject:view];
        }
        
        [self refreshStickyHeadersContainersHeight];
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if (_enableStickyHeaders)
    {
        UIView *firstDisplayedSectionHeader = displayedSectionHeaders.firstObject;
        if (firstDisplayedSectionHeader)
        {
            if (section == firstDisplayedSectionHeader.tag)
            {
                [displayedSectionHeaders removeObjectAtIndex:0];
                
                [self refreshStickyHeadersContainersHeight];
            }
            else
            {
                // This section header is the last displayed one.
                // Add a sanity check in case of the header has been already removed.
                UIView *lastDisplayedSectionHeader = displayedSectionHeaders.lastObject;
                if (section == lastDisplayedSectionHeader.tag)
                {
                    [displayedSectionHeaders removeLastObject];
                    
                    [self refreshStickyHeadersContainersHeight];
                }
            }
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self refreshStickyHeadersContainersHeight];
        
    });
    
    [super scrollViewDidScroll:scrollView];
}

#pragma mark - Table view scrolling

- (void)scrollToTop:(BOOL)animated
{
    [self.recentsTableView setContentOffset:CGPointMake(-self.recentsTableView.adjustedContentInset.left, -self.recentsTableView.adjustedContentInset.top) animated:animated];
}

- (void)scrollToTheTopTheNextRoomWithMissedNotificationsInSection:(NSInteger)section
{
    if (section < 0)
    {
        return;
    }
    
    UITableViewCell *firstVisibleCell;
    NSIndexPath *firstVisibleCellIndexPath;
    
    UIView *firstSectionHeader = displayedSectionHeaders.firstObject;
    
    if (firstSectionHeader && firstSectionHeader.frame.origin.y <= self.recentsTableView.contentOffset.y)
    {
        // Compute the height of the hidden part of the section header.
        CGFloat hiddenPart = self.recentsTableView.contentOffset.y - firstSectionHeader.frame.origin.y;
        CGFloat firstVisibleCellPosY = self.recentsTableView.contentOffset.y + (firstSectionHeader.frame.size.height - hiddenPart);
        firstVisibleCellIndexPath = [self.recentsTableView indexPathForRowAtPoint:CGPointMake(0, firstVisibleCellPosY)];
        firstVisibleCell = [self.recentsTableView cellForRowAtIndexPath:firstVisibleCellIndexPath];
    }
    else
    {
        firstVisibleCell = self.recentsTableView.visibleCells.firstObject;
        firstVisibleCellIndexPath = [self.recentsTableView indexPathForCell:firstVisibleCell];
    }
    
    if (firstVisibleCell)
    {
        NSInteger nextCellRow = (firstVisibleCellIndexPath.section == section) ? firstVisibleCellIndexPath.row + 1 : 0;
        
        // Look for the next room with missed notifications.
        NSIndexPath *nextIndexPath = [NSIndexPath indexPathForRow:nextCellRow inSection:section];
        nextCellRow++;
        id<MXKRecentCellDataStoring> cellData = [self.dataSource cellDataAtIndexPath:nextIndexPath];
        
        while (cellData)
        {
            if (cellData.notificationCount)
            {
                [self.recentsTableView scrollToRowAtIndexPath:nextIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
                break;
            }
            nextIndexPath = [NSIndexPath indexPathForRow:nextCellRow inSection:section];
            nextCellRow++;
            cellData = [self.dataSource cellDataAtIndexPath:nextIndexPath];
        }
        
        if (!cellData && [self.recentsTableView numberOfRowsInSection:section] > 0)
        {
            // Scroll back to the top.
            [self.recentsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section] atScrollPosition:UITableViewScrollPositionTop animated:YES];
        }
    }
}

#pragma mark - MXKRecentListViewControllerDelegate

- (void)recentListViewController:(MXKRecentListViewController *)recentListViewController didSelectRoom:(NSString *)roomId inMatrixSession:(MXSession *)matrixSession
{
}

#pragma mark - CreateRoomCoordinatorBridgePresenterDelegate

//- (void)createRoomCoordinatorBridgePresenterDelegate:(CreateRoomCoordinatorBridgePresenter *)coordinatorBridgePresenter didCreateNewRoom:(MXRoom *)room
//{
//    [coordinatorBridgePresenter dismissWithAnimated:YES completion:^{
//        [self showRoomWithRoomId:room.roomId inMatrixSession:self.mainSession];
//    }];
//    coordinatorBridgePresenter = nil;
//}

//- (void)createRoomCoordinatorBridgePresenterDelegateDidCancel:(CreateRoomCoordinatorBridgePresenter *)coordinatorBridgePresenter
//{
//    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
//    coordinatorBridgePresenter = nil;
//}

#pragma mark - Empty view management

- (void)showEmptyViewIfNeeded
{
//    [self showEmptyView:[self shouldShowEmptyView]];
}

//- (void)showEmptyView:(BOOL)show
//{
//    if (!self.viewIfLoaded)
//    {
//        return;
//    }
//
//    if (show && !self.emptyView)
//    {
//        RootTabEmptyView *emptyView = [RootTabEmptyView instantiate];
//        [emptyView updateWithTheme:ThemeService.shared.theme];
//        [self addEmptyView:emptyView];
//
//        self.emptyView = emptyView;
//
//        [self updateEmptyView];
//    }
//    else if (!show)
//    {
//        [self.emptyView removeFromSuperview];
//    }
//
//    self.recentsTableView.hidden = show;
//    self.stickyHeadersTopContainer.hidden = show;
//    self.stickyHeadersBottomContainer.hidden = show;
//}
//
//- (void)updateEmptyView
//{
//
//}
//
//- (void)addEmptyView:(RootTabEmptyView*)emptyView
//{
//    if (!self.isViewLoaded)
//    {
//        return;
//    }
//
//    NSLayoutConstraint *emptyViewBottomConstraint;
//    NSLayoutConstraint *contentViewBottomConstraint;
//
//    if (plusButtonImageView && plusButtonImageView.isHidden == NO)
//    {
//        [self.view insertSubview:emptyView belowSubview:plusButtonImageView];
//
//        contentViewBottomConstraint = [NSLayoutConstraint constraintWithItem:emptyView.contentView
//                                                                   attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationLessThanOrEqual toItem:plusButtonImageView
//                                                                   attribute:NSLayoutAttributeTop
//                                                                  multiplier:1.0
//                                                                    constant:0];
//    }
//    else
//    {
//        [self.view addSubview:emptyView];
//    }
//
//    emptyViewBottomConstraint = [emptyView.bottomAnchor constraintEqualToAnchor:emptyView.superview.bottomAnchor];
//
//    emptyView.translatesAutoresizingMaskIntoConstraints = NO;
//
//    [NSLayoutConstraint activateConstraints:@[
//        [emptyView.topAnchor constraintEqualToAnchor:emptyView.superview.topAnchor],
//        [emptyView.leftAnchor constraintEqualToAnchor:emptyView.superview.leftAnchor],
//        [emptyView.rightAnchor constraintEqualToAnchor:emptyView.superview.rightAnchor],
//        emptyViewBottomConstraint
//    ]];
//
//    if (contentViewBottomConstraint)
//    {
//        contentViewBottomConstraint.active = YES;
//    }
//}

- (BOOL)shouldShowEmptyView
{
    return NO;
}

#pragma mark - RoomsDirectoryCoordinatorBridgePresenterDelegate

//- (void)roomsDirectoryCoordinatorBridgePresenterDelegateDidComplete:(RoomsDirectoryCoordinatorBridgePresenter *)coordinatorBridgePresenter
//{
//    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
//    self.roomsDirectoryCoordinatorBridgePresenter = nil;
//}

//- (void)roomsDirectoryCoordinatorBridgePresenterDelegate:(RoomsDirectoryCoordinatorBridgePresenter *)coordinatorBridgePresenter didSelectRoom:(MXPublicRoom *)room
//{
//    [coordinatorBridgePresenter dismissWithAnimated:YES completion:^{
//        [self openPublicRoom:room];
//    }];
//    self.roomsDirectoryCoordinatorBridgePresenter = nil;
//}

//- (void)roomsDirectoryCoordinatorBridgePresenterDelegateDidTapCreateNewRoom:(RoomsDirectoryCoordinatorBridgePresenter *)coordinatorBridgePresenter
//{
//    [coordinatorBridgePresenter dismissWithAnimated:YES completion:^{
//        [self createNewRoom];
//    }];
//    self.roomsDirectoryCoordinatorBridgePresenter = nil;
//}

//- (void)roomsDirectoryCoordinatorBridgePresenterDelegate:(RoomsDirectoryCoordinatorBridgePresenter *)coordinatorBridgePresenter didSelectRoomWithIdOrAlias:(NSString * _Nonnull)roomIdOrAlias
//{
//    MXRoom *room = [self.mainSession vc_roomWithIdOrAlias:roomIdOrAlias];
//
//    if (room)
//    {
//        // Room is known show it directly
//        [coordinatorBridgePresenter dismissWithAnimated:YES completion:^{
//            [self showRoomWithRoomId:room.roomId
//                     inMatrixSession:self.mainSession];
//        }];
//        coordinatorBridgePresenter = nil;
//    }
//    else if ([MXTools isMatrixRoomAlias:roomIdOrAlias])
//    {
//        // Room preview doesn't support room alias
//        [[AppDelegate theDelegate] showAlertWithTitle:[MatrixKitL10n error] message:[VectorL10n roomRecentsUnknownRoomErrorMessage]];
//    }
//    else
//    {
//        // Try to preview the room from his id
//        RoomPreviewData *roomPreviewData = [[RoomPreviewData alloc] initWithRoomId:roomIdOrAlias
//                                                                        andSession:self.mainSession];
//
//        [self startActivityIndicator];
//
//        // Try to get more information about the room before opening its preview
//        MXWeakify(self);
//
//        [roomPreviewData peekInRoom:^(BOOL succeeded) {
//
//            MXStrongifyAndReturnIfNil(self);
//
//            [self stopActivityIndicator];
//
//            if (succeeded) {
//                [coordinatorBridgePresenter dismissWithAnimated:YES completion:^{
//                    [self showRoomPreviewWithData:roomPreviewData];
//                }];
//                self.roomsDirectoryCoordinatorBridgePresenter = nil;
//            } else {
//                [[AppDelegate theDelegate] showAlertWithTitle:[MatrixKitL10n error] message:[VectorL10n roomRecentsUnknownRoomErrorMessage]];
//            }
//        }];
//    }
//}

#pragma mark - ExploreRoomCoordinatorBridgePresenterDelegate

//- (void)exploreRoomCoordinatorBridgePresenterDelegateDidComplete:(ExploreRoomCoordinatorBridgePresenter *)coordinatorBridgePresenter {
//    MXWeakify(self);
//    [coordinatorBridgePresenter dismissWithAnimated:YES completion:^{
//        MXStrongifyAndReturnIfNil(self);
//        self.exploreRoomsCoordinatorBridgePresenter = nil;
//    }];
//}

#pragma mark - RoomNotificationSettingsCoordinatorBridgePresenterDelegate
-(void)roomNotificationSettingsCoordinatorBridgePresenterDelegateDidComplete:(RoomNotificationSettingsCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.roomNotificationSettingsCoordinatorBridgePresenter = nil;
}

@end
