/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 Vector Creations Ltd
 
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

#import "SegmentedViewController.h"

#import "DesignValues.h"

#import "GeneratedInterface-Swift.h"

@interface SegmentedViewController ()
{
    // Tell whether the segmented view is appeared (see viewWillAppear/viewWillDisappear).
    BOOL isViewAppeared;
    
    // list of displayed UIViewControllers
    NSArray* viewControllers;
    
    // The constraints of the displayed viewController
    NSLayoutConstraint *displayedVCTopConstraint;
    NSLayoutConstraint *displayedVCLeftConstraint;
    NSLayoutConstraint *displayedVCWidthConstraint;
    NSLayoutConstraint *displayedVCHeightConstraint;
    
    // list of NSString
    NSArray* sectionTitles;
    
    // list of section labels
    NSArray* sectionLabels;
    
    // the selected marker view
    UIView* selectedMarkerView;
    NSLayoutConstraint *leftMarkerViewConstraint;
    
    // Observe kRiotDesignValuesDidChangeThemeNotification to handle user interface theme change.
    id kRiotDesignValuesDidChangeThemeNotificationObserver;
}

@property (nonatomic, strong) id<Style> currentStyle;

@end

@implementation SegmentedViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([SegmentedViewController class])
                          bundle:[NSBundle bundleForClass:[SegmentedViewController class]]];
}

+ (instancetype)instantiate
{
    SegmentedViewController *segmentedViewController = [[[self class] alloc] initWithNibName:NSStringFromClass([SegmentedViewController class])
                                          bundle:[NSBundle bundleForClass:[SegmentedViewController class]]];
    segmentedViewController.currentStyle = Variant1Style.shared;
    return segmentedViewController;
}

/**
 init the segmentedViewController with a list of UIViewControllers.
 @param titles the section tiles
 @param viewControllers the list of viewControllers to display.
 @param defaultSelected index of the default selected UIViewController in the list.
 */
- (void)initWithTitles:(NSArray*)titles viewControllers:(NSArray*)someViewControllers defaultSelected:(NSUInteger)defaultSelected
{
    viewControllers = someViewControllers;
    sectionTitles = titles;
    _selectedIndex = defaultSelected;
}

- (void)destroy
{
    for (id viewController in viewControllers)
    {
        if ([viewController respondsToSelector:@selector(destroy)])
        {
            [viewController destroy];
        }
    }
    viewControllers = nil;
    sectionTitles = nil;
    
    sectionLabels = nil;
    
    if (selectedMarkerView)
    {
        [selectedMarkerView removeFromSuperview];
        selectedMarkerView = nil;
    }
    
    if (kRiotDesignValuesDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kRiotDesignValuesDidChangeThemeNotificationObserver];
        kRiotDesignValuesDidChangeThemeNotificationObserver = nil;
    }
    
    [super destroy];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    if (_selectedIndex != selectedIndex)
    {
        _selectedIndex = selectedIndex;
        [self displaySelectedViewController];
    }
}

- (NSArray<UIViewController *> *)viewControllers
{
    return viewControllers;
}

#pragma mark -

- (void)finalizeInit
{
    [super finalizeInit];
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Check whether the view controller has been pushed via storyboard
    if (!self.viewControllerContainer)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }

    // Adjust Top
    [NSLayoutConstraint deactivateConstraints:@[self.selectionContainerTopConstraint]];
    
    // it is not possible to define a constraint to the topLayoutGuide in the xib editor
    // so do it in the code ..
    self.selectionContainerTopConstraint = [NSLayoutConstraint constraintWithItem:self.topLayoutGuide
                                                                  attribute:NSLayoutAttributeBottom
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.selectionContainer
                                                                  attribute:NSLayoutAttributeTop
                                                                 multiplier:1.0f
                                                                   constant:0.0f];
    
    [NSLayoutConstraint activateConstraints:@[self.selectionContainerTopConstraint]];
    
    // Observe user interface theme change.
    kRiotDesignValuesDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kRiotDesignValuesDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self userInterfaceThemeDidChange];
        
    }];
    [self userInterfaceThemeDidChange];
    
    [self createSegmentedViews];
}

- (void)userInterfaceThemeDidChange
{
    [self updateStyle:self.currentStyle];
}

- (void)updateStyle:(id<Style>)style
{
    self.currentStyle = style;
    
    self.sectionHeaderTintColor = style.barActionColor;
    
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    
    if (navigationBar)
    {
        [style applyStyleOnNavigationBar:navigationBar];
    }
    
    self.view.backgroundColor = style.backgroundColor;
    
    // @TODO Design the activvity indicator for Tchap
    self.activityIndicator.backgroundColor = kRiotOverlayColor;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return self.currentStyle.statusBarStyle;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (_selectedViewController)
    {
        // Make iOS invoke child viewWillAppear
        [_selectedViewController beginAppearanceTransition:YES animated:animated];
    }
    
    isViewAppeared = YES;
    
    // Apply the current theme
    [self userInterfaceThemeDidChange];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (_selectedViewController)
    {
        // Make iOS invoke child viewWillDisappear
        [_selectedViewController beginAppearanceTransition:NO animated:animated];
    }
    
    isViewAppeared = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (_selectedViewController)
    {
        // Make iOS invoke child viewDidAppear
        [_selectedViewController endAppearanceTransition];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (_selectedViewController)
    {
        // Make iOS invoke child viewDidDisappear
        [_selectedViewController endAppearanceTransition];
    }
}

- (void)createSegmentedViews
{
    NSMutableArray* labels = [[NSMutableArray alloc] init];
    
    NSUInteger count = viewControllers.count;
    
    for (NSUInteger index = 0; index < count; index++)
    {
        // create programmatically each label
        UILabel *label = [[UILabel alloc] init];
        
        label.text = [sectionTitles objectAtIndex:index];
        label.font = [UIFont systemFontOfSize:17];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = _sectionHeaderTintColor;
        label.backgroundColor = self.currentStyle.barBackgroundColor;
        label.accessibilityIdentifier = [NSString stringWithFormat:@"SegmentedVCSectionLabel%tu", index];
        
        // the constraint defines the label frame
        // so ignore any autolayout stuff
        [label setTranslatesAutoresizingMaskIntoConstraints:NO];
        
        // add the label before setting the constraints
        [self.selectionContainer addSubview:label];
    
        NSLayoutConstraint *leftConstraint;
        if (labels.count)
        {
            leftConstraint = [NSLayoutConstraint constraintWithItem:label
                                                          attribute:NSLayoutAttributeLeading
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:[labels objectAtIndex:(index-1)]
                                                          attribute:NSLayoutAttributeTrailing
                                                         multiplier:1.0
                                                           constant:0];
        }
        else
        {
            leftConstraint = [NSLayoutConstraint constraintWithItem:label
                                         attribute:NSLayoutAttributeLeading
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:self.selectionContainer
                                         attribute:NSLayoutAttributeLeading
                                        multiplier:1.0
                                          constant:0];
        }
        
        NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:label
                                                                           attribute:NSLayoutAttributeWidth
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:self.selectionContainer
                                                                           attribute:NSLayoutAttributeWidth
                                                                          multiplier:1.0 / count
                                                                            constant:0];
        
        NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:label
                                                                         attribute:NSLayoutAttributeTop
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.selectionContainer
                                                                         attribute:NSLayoutAttributeTop
                                                                        multiplier:1.0
                                                                          constant:0];
        
        
        
        NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:label
                                                                            attribute:NSLayoutAttributeHeight
                                                                            relatedBy:NSLayoutRelationEqual
                                                                               toItem:self.selectionContainer
                                                                            attribute:NSLayoutAttributeHeight
                                                                           multiplier:1.0
                                                                             constant:0];
        
        
        // set the constraints
        [NSLayoutConstraint activateConstraints:@[leftConstraint, rightConstraint, topConstraint, heightConstraint]];
        
        UITapGestureRecognizer *labelTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onLabelTouch:)];
        [labelTapGesture setNumberOfTouchesRequired:1];
        [labelTapGesture setNumberOfTapsRequired:1];
        label.userInteractionEnabled = YES;
        [label addGestureRecognizer:labelTapGesture];
            
        [labels addObject:label];
    }
    
    sectionLabels = labels;
    
    [self addSelectedMarkerView];
    
    [self displaySelectedViewController];
}

- (void)addSelectedMarkerView
{
    // Sanity check
    NSAssert(sectionLabels.count, @"[SegmentedViewController] addSelectedMarkerView failed - At least one view controller is required");

    // create the selected marker view
    selectedMarkerView = [[UIView alloc] init];
    selectedMarkerView.backgroundColor = _sectionHeaderTintColor;
    [selectedMarkerView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.selectionContainer addSubview:selectedMarkerView];
    
    leftMarkerViewConstraint = [NSLayoutConstraint constraintWithItem:selectedMarkerView
                                                            attribute:NSLayoutAttributeLeading
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:[sectionLabels objectAtIndex:_selectedIndex]
                                                            attribute:NSLayoutAttributeLeading
                                                           multiplier:1.0
                                                             constant:0];
    
    
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:selectedMarkerView
                                                                       attribute:NSLayoutAttributeWidth
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:self.selectionContainer
                                                                       attribute:NSLayoutAttributeWidth
                                                                      multiplier:1.0 / sectionLabels.count
                                                                        constant:0];
    
    NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:selectedMarkerView
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self.selectionContainer
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0
                                                                         constant:0];
    
    
    
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:selectedMarkerView
                                                                        attribute:NSLayoutAttributeHeight
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:nil
                                                                        attribute:NSLayoutAttributeNotAnAttribute
                                                                       multiplier:1.0
                                                                         constant:3];
    
    // set the constraints
    [NSLayoutConstraint activateConstraints:@[leftMarkerViewConstraint, widthConstraint, bottomConstraint, heightConstraint]];
}

- (void)displaySelectedViewController
{
    // Sanity check
    NSAssert(sectionLabels.count, @"[SegmentedViewController] displaySelectedViewController failed - At least one view controller is required");

    if (_selectedViewController)
    {
        NSUInteger index = [viewControllers indexOfObject:_selectedViewController];
        
        if (index != NSNotFound)
        {
            UILabel* label = [sectionLabels objectAtIndex:index];
            label.font = [UIFont systemFontOfSize:17];
        }
        
        [_selectedViewController willMoveToParentViewController:nil];
        
        [_selectedViewController.view removeFromSuperview];
        [_selectedViewController removeFromParentViewController];
        
        [NSLayoutConstraint deactivateConstraints:@[displayedVCTopConstraint, displayedVCLeftConstraint, displayedVCWidthConstraint, displayedVCHeightConstraint]];
    }
    
    UILabel* label = [sectionLabels objectAtIndex:_selectedIndex];
    label.font = [UIFont boldSystemFontOfSize:17];

    // update the marker view position
    [NSLayoutConstraint deactivateConstraints:@[leftMarkerViewConstraint]];

    leftMarkerViewConstraint = [NSLayoutConstraint constraintWithItem:selectedMarkerView
                                                            attribute:NSLayoutAttributeLeading
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:[sectionLabels objectAtIndex:_selectedIndex]
                                                            attribute:NSLayoutAttributeLeading
                                                           multiplier:1.0
                                                             constant:0];

    [NSLayoutConstraint activateConstraints:@[leftMarkerViewConstraint]];

    // Set the new selected view controller
    _selectedViewController = [viewControllers objectAtIndex:_selectedIndex];

    // Make iOS invoke selectedViewController viewWillAppear when the segmented view is already visible
    if (isViewAppeared)
    {
        [_selectedViewController beginAppearanceTransition:YES animated:YES];
    }

    [self addChildViewController:_selectedViewController];
    
    [_selectedViewController.view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.viewControllerContainer addSubview:_selectedViewController.view];
    
    
    displayedVCTopConstraint = [NSLayoutConstraint constraintWithItem:_selectedViewController.view
                                                            attribute:NSLayoutAttributeTop
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:self.viewControllerContainer
                                                            attribute:NSLayoutAttributeTop
                                                           multiplier:1.0f
                                                             constant:0.0f];
    
    displayedVCLeftConstraint = [NSLayoutConstraint constraintWithItem:_selectedViewController.view
                                                             attribute:NSLayoutAttributeLeading
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.viewControllerContainer
                                                             attribute:NSLayoutAttributeLeading
                                                            multiplier:1.0f
                                                              constant:0.0f];
    
    displayedVCWidthConstraint = [NSLayoutConstraint constraintWithItem:_selectedViewController.view
                                                                        attribute:NSLayoutAttributeWidth
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self.viewControllerContainer
                                                                        attribute:NSLayoutAttributeWidth
                                                                       multiplier:1.0
                                                                         constant:0];
    
    displayedVCHeightConstraint = [NSLayoutConstraint constraintWithItem:_selectedViewController.view
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.viewControllerContainer
                                                              attribute:NSLayoutAttributeHeight
                                                             multiplier:1.0
                                                               constant:0];
    
    [NSLayoutConstraint activateConstraints:@[displayedVCTopConstraint, displayedVCLeftConstraint, displayedVCWidthConstraint, displayedVCHeightConstraint]];
    
    [_selectedViewController didMoveToParentViewController:self];
    
    // Make iOS invoke selectedViewController viewDidAppear when the segmented view is already visible
    if (isViewAppeared)
    {
        [_selectedViewController endAppearanceTransition];
    }
}

#pragma mark - touch event

- (void)onLabelTouch:(UIGestureRecognizer*)gestureRecognizer
{
    NSUInteger pos = [sectionLabels indexOfObject:gestureRecognizer.view];
    
    // check if there is an update before triggering anything
    if ((pos != NSNotFound) && (_selectedIndex != pos))
    {
        // update the selected index
        self.selectedIndex = pos;
    }
}

@end
