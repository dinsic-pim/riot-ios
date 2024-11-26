/*
Copyright 2024 New Vector Ltd.
Copyright 2017 Vector Creations Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "RoomsViewController.h"

#import "RecentsDataSource.h"

#import "GeneratedInterface-Swift.h"

@interface RoomsViewController () <MasterTabBarItemDisplayProtocol>
{
    RecentsDataSource *recentsDataSource;
}

@property (nonatomic, strong) MXThrottler *tableViewPaginationThrottler;
@property (nonatomic, weak) UIAlertController *currentAlertController;

@end

@implementation RoomsViewController

+ (instancetype)instantiate
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    RoomsViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"RoomsViewController"];
    return viewController;
}

- (void)finalizeInit
{
    [super finalizeInit];
    
    self.screenTracker = [[AnalyticsScreenTracker alloc] initWithScreen:AnalyticsScreenRooms];
    self.tableViewPaginationThrottler = [[MXThrottler alloc] initWithMinimumDelay:0.1];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.accessibilityIdentifier = @"RoomsVCView";
    self.recentsTableView.accessibilityIdentifier = @"RoomsVCTableView";
    
    // Tag the recents table with the its recents data source mode.
    // This will be used by the shared RecentsDataSource instance for sanity checks (see UITableViewDataSource methods).
    self.recentsTableView.tag = RecentsDataSourceModeRooms;
    
    // Add the (+) button programmatically
    plusButtonImageView = [self vc_addFABWithImage:AssetImages.roomsFloatingAction.image
                                            target:self
                                            action:@selector(onPlusButtonPressed)];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [AppDelegate theDelegate].masterTabBarController.tabBar.tintColor = ThemeService.shared.theme.tintColor;
    
    if ([self.dataSource isKindOfClass:RecentsDataSource.class])
    {
        // Take the lead on the shared data source.
        recentsDataSource = (RecentsDataSource*)self.dataSource;
        
        if (recentsDataSource.recentsDataSourceMode != RecentsDataSourceModeRooms)
        {
            // Take the lead on the shared data source.
            [recentsDataSource setDelegate:self andRecentsDataSourceMode:RecentsDataSourceModeRooms];
            
            // Reset filtering on the shared data source when switching tabs
            [recentsDataSource searchWithPatterns:nil];
            [self.recentsSearchBar setText:nil];
        }
    }

    // Tchap: Hide plus button if needed (is external user)
    NSString *userID = [UserSessionsService shared].mainUserSession.userId;
    [plusButtonImageView setHidden:[UserService isExternalUserFor:userID]];
}

- (void)destroy
{
    [super destroy];
}

#pragma mark - Override RecentsViewController

- (void)refreshCurrentSelectedCell:(BOOL)forceVisible
{
    // Check whether the recents data source is correctly configured.
    if (recentsDataSource.recentsDataSourceMode != RecentsDataSourceModeRooms)
    {
        return;
    }
    
    [super refreshCurrentSelectedCell:forceVisible];
}

- (void)onPlusButtonPressed
{
    // Tchap: Redirect to an AlertController.
    [self.currentAlertController dismissViewControllerAnimated:NO completion:nil];

    self.currentAlertController = [self showPlusMenuFrom:self->plusButtonImageView];
}

// Tchap: Fix dataSource for pagination.
- (void)displayList:(MXKRecentsDataSource *)listDataSource {
    [super displayList:listDataSource];
    
    if ([self.dataSource isKindOfClass:RecentsDataSource.class])
    {
        // Take the lead on the shared data source.
        recentsDataSource = (RecentsDataSource*)self.dataSource;
        recentsDataSource.areSectionsShrinkable = YES;
        [recentsDataSource setDelegate:self andRecentsDataSourceMode:RecentsDataSourceModeRooms];
    }
}

#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([super respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)])
    {
        [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    
    [self.tableViewPaginationThrottler throttle:^{
        NSInteger section = indexPath.section;
        if (tableView.numberOfSections <= section)
        {
            return;
        }

        NSInteger numberOfRowsInSection = [tableView numberOfRowsInSection:section];
        if (indexPath.row == numberOfRowsInSection - 1)
        {
            [self->recentsDataSource paginateInSection:section];
        }
    }];
}

#pragma mark - 

- (void)scrollToNextRoomWithMissedNotifications
{
    // Check whether the recents data source is correctly configured.
    if (recentsDataSource.recentsDataSourceMode == RecentsDataSourceModeRooms)
    {
        [self scrollToTheTopTheNextRoomWithMissedNotificationsInSection:[recentsDataSource.sections sectionIndexForSectionType:RecentsDataSourceSectionTypeConversation]];
    }
}

#pragma mark - Empty view management

- (void)updateEmptyView
{
    [self.emptyView fillWith:[self emptyViewArtwork]
                       title:[VectorL10n roomsEmptyViewTitle]
             informationText:[VectorL10n roomsEmptyViewInformation]];
}

- (UIImage*)emptyViewArtwork
{
    if (ThemeService.shared.isCurrentThemeDark)
    {
        return AssetImages.roomsEmptyScreenArtworkDark.image;
    }
    else
    {
        return AssetImages.roomsEmptyScreenArtwork.image;
    }
}

#pragma mark - MasterTabBarItemDisplayProtocol

- (NSString *)masterTabBarItemTitle
{
    return [VectorL10n titleRooms];
}

@end
