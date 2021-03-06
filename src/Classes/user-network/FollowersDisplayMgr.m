//
//  Copyright High Order Bit, Inc. 2009. All rights reserved.
//

#import "FollowersDisplayMgr.h"
#import "UserNetworkDisplayMgr.h"
#import "GitHubService.h"
#import "UIAlertView+CreationHelpers.h"

@interface FollowersDisplayMgr (Private)

- (void)setUsername:(NSString *)aUsername;

@end

@implementation FollowersDisplayMgr

- (void)dealloc
{
    [navigationController release];

    [userNetworkDisplayMgr release];
    [gitHubService release];

    [username release];

    [super dealloc];
}

- (id)initWithNavigationController:(UINavigationController *)nc
                     gitHubService:(GitHubService *)aGitHubService
             userDisplayMgr:(NSObject<UserDisplayMgr> *)aUserDisplayMgr
{
    if (self = [super init]) {
        navigationController = [nc retain];

        userNetworkDisplayMgr =
            [[UserNetworkDisplayMgr alloc]
            initWithUserDisplayMgr:aUserDisplayMgr];
        userNetworkDisplayMgr.delegate = self;

        gitHubService = [aGitHubService retain];
        gitHubService.delegate = self;

        gitHubFailure = NO;
    }

    return self;
}

- (void)displayFollowersForUsername:(NSString *)aUsername
{
    [self setUsername:aUsername];

    gitHubFailure = NO;

    // Perform fetch after a brief delay because the results can be
    // returned before the navigation controller's push animation is
    // completed, which causes a weird UI glitch.
    SEL sel = @selector(fetchFollowersForUsername:);
    [gitHubService performSelector:sel withObject:username afterDelay:0.2];

    [userNetworkDisplayMgr setNetwork:nil forUsername:username];
    [userNetworkDisplayMgr setUpdatingState:kConnectedAndUpdating];

    [userNetworkDisplayMgr pushDisplay:navigationController];
}

#pragma mark UserNetworkDisplayMgrDelegate implementation

- (NSString *)titleForNavigationItem
{
    return NSLocalizedString(@"followers.view.title", @"");
}

- (UIBarButtonItem *)rightBarButtonItem
{
    UIBarButtonItem * refreshButtonItem =
        [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
        target:self
        action:@selector(refreshFollowers)];

    return [refreshButtonItem autorelease];
}

#pragma mark GitHubService protocol implementation

- (void)followers:(NSArray *)followers fetchedForUsername:(NSString *)aUsername
{
    gitHubFailure = NO;

    if ([username isEqualToString:aUsername]) {
        [userNetworkDisplayMgr setUpdatingState:kConnectedAndNotUpdating];
        [userNetworkDisplayMgr setNetwork:followers forUsername:aUsername];
    }
}

- (void)failedToFetchFollowersForUsername:(NSString *)aUsername
                                    error:(NSError *)error
{
    if ([username isEqualToString:aUsername] && !gitHubFailure) {
        gitHubFailure = YES;

        NSLog(@"Failed to retrieve follower list for user: '%@', error: '%@'.",
            username, error);

        NSString * title =
            NSLocalizedString(@"github.followersupdate.failed.alert.title",
            @"");
        NSString * message = error.localizedDescription;

        [[UIAlertView simpleAlertViewWithTitle:title message:message] show];

        [userNetworkDisplayMgr setUpdatingState:kDisconnected];
    }
}

#pragma mark Refreshing the display

- (void)refreshFollowers
{
    gitHubFailure = NO;

    [gitHubService fetchFollowersForUsername:username];

    [userNetworkDisplayMgr setUpdatingState:kConnectedAndUpdating];
}

#pragma mark Accessors

- (void)setUsername:(NSString *)aUsername
{
    NSString * tmp = [aUsername copy];
    [username release];
    username = tmp;
}

@end
