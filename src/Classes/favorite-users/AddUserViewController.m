//
//  Copyright 2009 High Order Bit, Inc. All rights reserved.
//

#import "AddUserViewController.h"

static const NSInteger NUM_SECTIONS = 2;
enum Sections
{
    kCredentialsSection,
    kHelpSection
};

static const NSInteger NUM_CREDENTIALS_ROWS = 1;
enum CredentialsSection
{
    kUsernameRow
};

static const NSInteger NUM_HELP_ROWS = 1;
enum HelpSection
{
    kHelpRow
};

@interface AddUserViewController (Private)

@property (readonly) NameValueTextEntryTableViewCell * usernameCell;
@property (readonly) UITableViewCell * helpCell;

- (void)userDidSave;
- (void)userDidCancel;
- (BOOL)checkUsernameValid:(NSString *)text;
- (void)updateUIForCommunicating;

@end

@implementation AddUserViewController

@synthesize delegate;
@synthesize favoriteUsersStateReader;

- (void)dealloc
{
    [delegate release];
    [favoriteUsersStateReader release];
    [tableView release];
    [usernameCell release];
    [helpCell release];
    [usernameTextField release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = NSLocalizedString(@"adduser.view.title", @"");
    self.navigationItem.prompt = NSLocalizedString(@"adduser.view.prompt", @"");
    
    UIBarButtonItem * addUserButtonItem =
    [[UIBarButtonItem alloc]
     initWithTitle:NSLocalizedString(@"adduser.adduser.label", @"")
     style:UIBarButtonItemStyleDone
     target:self
     action:@selector(userDidSave)];
    addUserButtonItem.enabled = NO;
    
    UIBarButtonItem * cancelButtonItem =
    [[UIBarButtonItem alloc]
     initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
     target:self
     action:@selector(userDidCancel)];
    
    [self.navigationItem setRightBarButtonItem:addUserButtonItem animated:YES];
    [self.navigationItem setLeftBarButtonItem:cancelButtonItem animated:YES];
    
    [addUserButtonItem release];
    [cancelButtonItem release];
    
    usernameTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    usernameTextField.delegate = self;
    
    self.usernameCell.textField = usernameTextField;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.helpCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    NSIndexPath * selection = [tableView indexPathForSelectedRow];
    [tableView deselectRowAtIndexPath:selection animated:NO];
    
    self.usernameCell.nameLabel.text =
        NSLocalizedString(@"adduser.username.label", @"");
    
    [self.usernameCell.textField becomeFirstResponder];
    
    [self promptForUsername];
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
        case kCredentialsSection:
            nrows = NUM_CREDENTIALS_ROWS;
            break;
        case kHelpSection:
            nrows = NUM_HELP_ROWS;
            break;
    }
    
    return nrows;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tv
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell * cell;
    
    if (indexPath.section == kCredentialsSection)
        switch (indexPath.row) {
            case kUsernameRow:
                cell = self.usernameCell;
                break;
        }
    else if (indexPath.section == kHelpSection)
        switch (indexPath.row) {
            case kHelpRow:
                cell = self.helpCell;
                break;
        }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kHelpSection && indexPath.row == kHelpRow)
        [delegate provideHelp];
}

#pragma mark UITextFieldDelegate functions

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
    replacementString:(NSString *)string
{
    if (textField == usernameTextField) {
        NSString * text =
            [textField.text stringByReplacingCharactersInRange:range
            withString:string];

        self.navigationItem.rightBarButtonItem.enabled =
            [self checkUsernameValid:text];
    }
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([self checkUsernameValid:textField.text])
        [self userDidSave];

    return NO;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if (textField == usernameTextField)
        self.navigationItem.rightBarButtonItem.enabled = NO;
    
    return YES;
}

#pragma mark User actions

- (void)userDidSave
{
    self.helpCell.selectionStyle = UITableViewCellSelectionStyleNone;
    [self updateUIForCommunicating];
            
    NSString * username = usernameTextField.text;
    [delegate userProvidedUsername:username];
}

- (void)userDidCancel
{
    [delegate userDidCancel];
    self.usernameCell.textField.text = @"";
}

#pragma mark UI configuration

- (void)promptForUsername
{
    self.navigationItem.rightBarButtonItem.enabled =
        [self checkUsernameValid:usernameTextField.text];
    self.navigationItem.prompt = NSLocalizedString(@"adduser.view.prompt", @"");
    self.usernameCell.textField.enabled = YES;
}

- (void)updateUIForCommunicating
{
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.navigationItem.prompt =
        NSLocalizedString(@"adduser.communicating.prompt", @"");
    self.usernameCell.textField.enabled = NO;
}

- (void)usernameAccepted
{
    self.usernameCell.textField.text = @"";
}

#pragma mark Accessors

- (NameValueTextEntryTableViewCell *)usernameCell
{
    if (!usernameCell)
        usernameCell =
        [[NameValueTextEntryTableViewCell createCustomInstance] retain];
    
    return usernameCell;
}

- (UITableViewCell *)helpCell
{
    if (helpCell == nil) {
        static NSString * reuseIdentifier = @"HelpTableViewCell";
        
        helpCell =
        [[UITableViewCell
          createStandardInstanceWithReuseIdentifier:reuseIdentifier]
         retain];
        helpCell.text = NSLocalizedString(@"login.help.label", @"");
        helpCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return helpCell;
}

#pragma mark Helper methods

- (BOOL)checkUsernameValid:(NSString *)text
{
    NSArray * favoriteUsers = favoriteUsersStateReader.favoriteUsers;
    
    return text.length > 0 && ![favoriteUsers containsObject:text];
}

@end
