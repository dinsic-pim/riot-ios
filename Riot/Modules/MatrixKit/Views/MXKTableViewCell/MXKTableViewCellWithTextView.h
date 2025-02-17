/*
Copyright 2024 New Vector Ltd.
Copyright 2015 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "MXKTableViewCell.h"

/**
 'MXKTableViewCellWithTextView' inherits 'MXKTableViewCell' class.
 It constains a 'UITextView' vertically centered.
 */
@interface MXKTableViewCellWithTextView : MXKTableViewCell

@property (strong, nonatomic) IBOutlet UITextView *mxkTextView;
@property (strong, nonatomic) IBOutlet UIImageView *mxkIconView;

/**
 Leading/Trailing constraints define here spacing to nearest neighbor (no relative to margin)
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mxkTextViewLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mxkTextViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mxkTextViewBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mxkTextViewTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mxkIconWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mxkIconTextSpacingConstraint;

-(void)setIcon:(UIImage *)icon withTint:(UIColor *)tintColor; // Tchap set only

@end
