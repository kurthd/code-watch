//
//  Copyright High Order Bit, Inc. 2009. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CommitViewControllerDelegate.h"

@class CommitInfo;

@interface CommitViewController : UITableViewController
{
    IBOutlet NSObject<CommitViewControllerDelegate> * delegate;

    IBOutlet UIView * headerView;

    IBOutlet UILabel * nameLabel;
    IBOutlet UIButton * emailButton;
    IBOutlet UILabel * timestampLabel;
    IBOutlet UILabel * messageLabel;
    IBOutlet UIImageView * avatarImageView;

    NSString * repoName;
    CommitInfo * commitInfo;
    UIImage * avatar;
}

@property (nonatomic, copy, readonly) NSString * repoName;
@property (nonatomic, copy, readonly) CommitInfo * commitInfo;
@property (nonatomic, retain, readonly) UIImage * avatar;

// TODO: Remove when wired in the nib
@property (nonatomic, retain) NSObject<CommitViewControllerDelegate> * delegate;

- (void)scrollToTop;
- (IBAction)sendEmail:(id)sender;

#pragma mark Updating the view with new data

- (void)updateWithCommitInfo:(CommitInfo *)info forRepo:(NSString *)repo;
- (void)updateWithAvatar:(UIImage *)avatar;

@end
