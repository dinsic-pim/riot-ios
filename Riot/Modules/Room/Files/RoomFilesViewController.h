/*
Copyright 2024 New Vector Ltd.
Copyright 2016 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
*/

#import "MatrixKit.h"

@class AnalyticsScreenTracker;

/**
 This view controller displays the attachments of a room. Only one matrix session is handled by this view controller.
 */
@interface RoomFilesViewController : MXKRoomViewController

/**
 Creates and returns a new `RoomFilesViewController` object.
 
 @discussion This is the designated initializer for programmatic instantiation.
 @return An initialized `RoomFilesViewController` object if successful, `nil` otherwise.
 */
+ (instancetype)instantiate;

@property (nonatomic) BOOL showCancelBarButtonItem;

/**
 The screen timer used for analytics if they've been enabled. The default value is nil.
 */
@property (nonatomic) AnalyticsScreenTracker *screenTracker;

@end
