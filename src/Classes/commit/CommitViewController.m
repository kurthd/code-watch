//
//  Copyright High Order Bit, Inc. 2009. All rights reserved.
//

#import "CommitViewController.h"
#import "CommitInfo.h"
#import "UIColor+CodeWatchColors.h"

static const NSUInteger NUM_SECTIONS = 2;
enum
{
    kDiffSection,
    kActionSection
} kSections;

static const NSUInteger NUM_DIFF_ROWS = 3;
enum
{
    kRemovedRow,
    kAddedRow,
    kModifiedRow
} kDiffRows;

static const NSUInteger NUM_ACTION_ROWS = 2;
enum
{
    kSafariRow,
    kEmailRow
};

@interface CommitViewController (Private)
- (void)formatDiffCell:(UITableViewCell *)cell
         withChangeset:(NSArray *)changes
  singularFormatString:(NSString *)singularFormatString
    pluralFormatString:(NSString *)pluralFormatString;
- (void)setCommitInfo:(CommitInfo *)info;
@end

@implementation CommitViewController

@synthesize delegate, commitInfo;

- (void)dealloc
{
    [delegate release];

    [headerView release];

    [avatarImageView release];
    [nameLabel release];
    [emailLabel release];
    [messageLabel release];

    [commitInfo release];

    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    headerView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.tableView.tableHeaderView = headerView;
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
    return NUM_SECTIONS;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tv
 numberOfRowsInSection:(NSInteger)section
{
    NSInteger nrows = 0;

    switch (section) {
        case kDiffSection:
            nrows = NUM_DIFF_ROWS;
            break;
        case kActionSection:
            nrows = NUM_ACTION_ROWS;
            break;
    }

    return nrows;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tv
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * CellIdentifier = @"CommitViewTableViewCell";

    UITableViewCell * cell =
        [tv dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil)
        cell =
            [[[UITableViewCell alloc]
              initWithFrame:CGRectZero reuseIdentifier:CellIdentifier]
             autorelease];

    switch (indexPath.section) {
        case kDiffSection: {
            NSString * pluralFormatString, * singularFormatString;
            NSArray * changeset;
            switch (indexPath.row) {
                case kAddedRow:
                    pluralFormatString =
                        NSLocalizedString(@"commit.added.plural.formatstring",
                            @"");
                    singularFormatString =
                        NSLocalizedString(@"commit.added.singular.formatstring",
                            @"");
                    changeset = [commitInfo.details objectForKey:@"added"];
                    break;
                case kRemovedRow:
                    pluralFormatString =
                        NSLocalizedString(@"commit.removed.plural.formatstring",
                            @"");
                    singularFormatString =
                        NSLocalizedString(
                            @"commit.removed.singular.formatstring",
                            @"");
                    changeset = [commitInfo.details objectForKey:@"removed"];
                    break;
                case kModifiedRow:
                    pluralFormatString =
                        NSLocalizedString(
                            @"commit.modified.plural.formatstring",
                            @"");
                    singularFormatString =
                        NSLocalizedString(
                            @"commit.modified.singular.formatstring",
                            @"");
                    changeset = [commitInfo.details objectForKey:@"modified"];
                    break;
            }
            [self formatDiffCell:cell withChangeset:changeset
                singularFormatString:singularFormatString
                pluralFormatString:pluralFormatString];
            break;
        }

        case kActionSection:
            switch (indexPath.row) {
                case kSafariRow:
                    cell.text = @"Open in Safari";
                    break;
                case kEmailRow:
                    cell.text = @"Email";
                    break;
            }
            break;
    }

    return cell;
}

- (NSIndexPath *) tableView:(UITableView *)tv
   willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kDiffSection) {
        NSArray * changeset = nil;
        switch (indexPath.row) {
            case kAddedRow:
                changeset = [commitInfo.details objectForKey:@"added"];
                break;
            case kRemovedRow:
                changeset = [commitInfo.details objectForKey:@"removed"];
                break;
            case kModifiedRow:
                changeset = [commitInfo.details objectForKey:@"modified"];
                break;
        }

        return changeset.count == 0 ? nil : indexPath;
    }

    return nil;
}

- (void)          tableView:(UITableView *)tv
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kDiffSection) {
        NSArray * changeset = nil;
        switch (indexPath.row) {
            case kAddedRow:
                changeset = [commitInfo.details objectForKey:@"added"];
                break;
            case kRemovedRow:
                changeset = [commitInfo.details objectForKey:@"removed"];
                break;
            case kModifiedRow:
                changeset = [commitInfo.details objectForKey:@"modified"];
                break;
        }

        [delegate userDidSelectChangeset:changeset];
    }
}

#pragma mark UI helpers

- (void)formatDiffCell:(UITableViewCell *)cell
         withChangeset:(NSArray *)changes
  singularFormatString:(NSString *)singularFormatString
    pluralFormatString:(NSString *)pluralFormatString
{
    NSString * text =
        changes.count == 1 ?
        [NSString stringWithFormat:singularFormatString, changes.count] :
        [NSString stringWithFormat:pluralFormatString, changes.count];

    UIColor * textColor = changes.count == 0 ?
        [UIColor codeWatchGrayColor] : [UIColor blackColor];

    UITableViewCellAccessoryType accessoryType =
        changes.count == 0 ?
        UITableViewCellAccessoryNone :
        UITableViewCellAccessoryDisclosureIndicator;

    UITableViewCellSelectionStyle selectionStyle =
        changes.count == 0 ?
        UITableViewCellSelectionStyleNone :
        UITableViewCellSelectionStyleBlue;

    cell.text = text;
    cell.textColor = textColor;
    cell.accessoryType = accessoryType;
    cell.selectionStyle = selectionStyle;
}

#pragma mark Updating the view with new data

- (void)updateWithCommitInfo:(CommitInfo *)info
{
    [self setCommitInfo:info];

    NSString * committerName =
        [[info.details objectForKey:@"committer"] objectForKey:@"name"];
    NSString * committerEmail =
        [[info.details objectForKey:@"committer"] objectForKey:@"email"];
    NSString * message = [info.details objectForKey:@"message"];

    nameLabel.text = committerName;
    emailLabel.text = committerEmail;

    CGSize maximumLabelSize = CGSizeMake(298.0, 9999.0);

    UIFont * font = messageLabel.font;
    CGSize size = [message sizeWithFont:font constrainedToSize:maximumLabelSize
        lineBreakMode:UILineBreakModeWordWrap];

    CGRect newFrame = messageLabel.frame;
    newFrame.size = size;

    messageLabel.frame = newFrame;
    messageLabel.text = message;

    CGRect headerFrame = headerView.frame;
    headerFrame.size.height = 85.0 + size.height;
    headerView.frame = headerFrame;

    self.tableView.tableHeaderView = headerView;

    [self.tableView reloadData];
}

#pragma mark Accessors

- (void)setCommitInfo:(CommitInfo *)info
{
    CommitInfo * tmp = [info copy];
    [commitInfo release];
    commitInfo = tmp;
}

@end
