//
//  Copyright High Order Bit, Inc. 2009. All rights reserved.
//

#import "RepoDisplayMgr.h"
#import "NetworkAwareViewController.h"
#import "RepoViewController.h"
#import "GitHubService.h"
#import "GravatarService.h"
#import "GravatarServiceFactory.h"
#import "UIAlertView+CreationHelpers.h"

@interface RepoDisplayMgr (Private)

- (void)addRefreshButton;

- (NSSet *)uniqueEmailsForCommits:(NSDictionary *)commits;
- (NSDictionary *)cachedAvatarsForEmailAddresses:(NSSet *)emailAddresses;
- (void)fetchAvatarsForEmailAddresses:(NSSet *)emailAddresses;

- (BOOL)loadCachedData;
- (RepoInfo *)cachedRepoInfoForUsername:(NSString *)username
                               repoName:(NSString *)repoName;
- (NSDictionary *)cachedCommitsForRepoInfo:(RepoInfo *)info;
- (BOOL)isPrimaryUser:(NSString *)username;

- (void)setUsername:(NSString *)username;
- (void)setRepoInfo:(RepoInfo *)info;
- (void)setRepoName:(NSString *)name;
- (void)setCommits:(NSDictionary *)someCommits;

- (GravatarService *)gravatarService;

@end

@implementation RepoDisplayMgr

@synthesize username, repoName, repoInfo, commits;

- (void)dealloc
{
    [username release];
    [repoName release];
    [repoInfo release];
    [commits release];
    [logInStateReader release];
    [repoCacheReader release];
    [avatarCacheReader release];
    [navigationController release];
    [networkAwareViewController release];
    [repoViewController release];
    [gitHubService release];
    [gravatarService release];
    [gravatarServiceFactory release];
    [commitSelector release];
    [super dealloc];
}

- (id)initWithLogInStateReader:
    (NSObject<LogInStateReader> *) aLogInStateReader
    repoCacheReader:
    (NSObject<RepoCacheReader> *) aRepoCacheReader
    commitCacheReader:
    (NSObject<CommitCacheReader> *) aCommitCacheReader
    avatarCacheReader:
    (NSObject<AvatarCacheReader> *)anAvatarCacheReader
    navigationController:
    (UINavigationController *) aNavigationController
    networkAwareViewController:
    (NetworkAwareViewController *) aNetworkAwareViewController
    repoViewController:
    (RepoViewController *) aRepoViewController
    gitHubService:
    (GitHubService *) aGitHubService
    gravatarServiceFactory:
    (GravatarServiceFactory *)aGravatarServiceFactory
    commitSelector:
    (NSObject<CommitSelector> *) aCommitSelector
{
    if (self = [super init]) {
        logInStateReader = [aLogInStateReader retain];
        repoCacheReader = [aRepoCacheReader retain];
        commitCacheReader = [aCommitCacheReader retain];
        avatarCacheReader = [anAvatarCacheReader retain];
        navigationController = [aNavigationController retain];
        networkAwareViewController = [aNetworkAwareViewController retain];
        repoViewController = [aRepoViewController retain];
        gitHubService = [aGitHubService retain];
        commitSelector = [aCommitSelector retain];

        gravatarServiceFactory = [aGravatarServiceFactory retain];

        [self addRefreshButton];
    }
    
    return self;
}

- (void)awakeFromNib
{
    [self addRefreshButton];
}

- (void)addRefreshButton
{
    UIBarButtonItem * refreshButton =
        [[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
        target:self
        action:@selector(refreshRepoInfo)] autorelease];

    [networkAwareViewController.navigationItem
        setRightBarButtonItem:refreshButton animated:NO];
}

- (void)refreshRepoInfo
{
    gitHubFailure = NO;
    avatarFailure = NO;
    
    BOOL cachedDataAvailable = [self loadCachedData];
    if (cachedDataAvailable) {
        [repoViewController updateWithCommits:commits
                                      forRepo:repoName
                                         info:repoInfo];

        NSSet * emails = [self uniqueEmailsForCommits:commits];
        NSDictionary * avatars = [self cachedAvatarsForEmailAddresses:emails];
        for (NSString * email in avatars) {
            UIImage * avatar = [avatars objectForKey:email];
            [repoViewController updateWithAvatar:avatar forEmailAddress:email];
        }
    }

    // refresh user info so we can refresh repo metadata (description, etc.)
    [gitHubService fetchInfoForUsername:username];

    networkAwareViewController.navigationItem.title =
        NSLocalizedString(@"repo.view.title", @"");

    [networkAwareViewController
        setNoConnectionText:
        NSLocalizedString(@"nodata.noconnection.text", @"")];
    [networkAwareViewController setUpdatingState:kConnectedAndUpdating];
    [networkAwareViewController setCachedDataAvailable:cachedDataAvailable];    
}

#pragma mark RepoSelector implementation

- (void)user:(NSString *)user didSelectRepo:(NSString *)repo
{
    BOOL needsToScrollToTop =
        ![username isEqualToString:user] || ![repoName isEqualToString:repo];

    [self setUsername:user];
    [self setRepoName:repo];
    
    [self refreshRepoInfo];

    [navigationController
        pushViewController:networkAwareViewController animated:YES];

    if (needsToScrollToTop)
        [repoViewController scrollToTop];
}

#pragma mark GitHubServiceDelegate implementation

- (void)userInfo:(UserInfo *)info repoInfos:(NSDictionary *)repos
    fetchedForUsername:(NSString *)updatedUsername
{
    if (![username isEqualToString:updatedUsername])
        return;  // this is not the update we're waiting for

    //
    // HACK: Because GitHub sometimes gives us incorrect user/repo
    // ownership data (e.g. jad/code-watch rather than
    // highorderbit/code-watch), we track whether or not the repo we're
    // looking for has been found in the retrieved list. If not, display an
    // error and update the display as approprate.
    //
    BOOL found = NO;

    for (NSString * repo in repos.allKeys)
        if ([repoName isEqualToString:repo]) {
            [self setRepoInfo:[repos objectForKey:repo]];
            // get the commit details
            [gitHubService fetchInfoForRepo:repo username:updatedUsername];
            found = YES;

            break;
        }

    if (!found) {
        NSString * title =
            NSLocalizedString(@"github.repoupdate.failed.alert.title", @"");
        NSString * message =
            [NSString stringWithFormat:
            NSLocalizedString(@"github.repoupdate.failed.message.formatstring",
            @""),
            updatedUsername, repoName];

        [[UIAlertView simpleAlertViewWithTitle:title message:message] show];

        [networkAwareViewController setNoConnectionText:
            NSLocalizedString(@"github.repoupdate.failed.noconnection.text",
            @"")];
        [networkAwareViewController setUpdatingState:kDisconnected];
    }
}

- (void)failedToFetchInfoForUsername:(NSString *)user
                               error:(NSError *)error
{
    if (![username isEqualToString:user])
        return;  // this is not the update we're waiting for

    if (!gitHubFailure) {
        gitHubFailure = YES;
        
        NSLog(@"Failed to retrieve info for user: '%@' error: '%@'.", user,
            error);

        NSString * title =
            NSLocalizedString(@"github.repoupdate.failed.alert.title", @"");
        NSString * cancelTitle =
            NSLocalizedString(@"github.repoupdate.failed.alert.ok", @"");
        NSString * message = error.localizedDescription;

        UIAlertView * alertView =
            [[[UIAlertView alloc]
              initWithTitle:title
                    message:message
                   delegate:self
          cancelButtonTitle:cancelTitle
          otherButtonTitles:nil]
             autorelease];

        [alertView show];

        [networkAwareViewController
            setNoConnectionText:
            NSLocalizedString(@"nodata.noconnection.text", @"")];
        [networkAwareViewController setUpdatingState:kDisconnected];
    }
}

- (void)commits:(NSDictionary*)newCommits
 fetchedForRepo:(NSString *)repo
       username:(NSString *)user
{
    if (![username isEqualToString:user] || ![repoName isEqualToString:repo])
        return;  // this is not the update we're waiting for

    [self setUsername:user];
    [self setRepoName:repo];

    RepoInfo * info = [self cachedRepoInfoForUsername:user repoName:repo];
    [self setRepoInfo:info];

    [self setCommits:newCommits];

    // update display with commits
    [repoViewController updateWithCommits:commits
                                  forRepo:repoName
                                     info:repoInfo];

    // update display with cached avatars
    NSSet * emails = [self uniqueEmailsForCommits:commits];
    NSDictionary * cachedAvatars = [self cachedAvatarsForEmailAddresses:emails];
    for (NSString * email in cachedAvatars) {
        UIImage * avatar = [cachedAvatars objectForKey:email];
        [repoViewController updateWithAvatar:avatar forEmailAddress:email];
    }

    if (emails.count > 0)
        [self fetchAvatarsForEmailAddresses:emails];

    BOOL dataWasCached = networkAwareViewController.cachedDataAvailable;

    // We set the state to connected and updating even though we might be
    // fetching avatars because we don't track the avatars that we're
    // waiting for and update the display after they've all been received.
    // Consider refactoring to provide the correct display later.
    [networkAwareViewController setUpdatingState:kConnectedAndNotUpdating];
    [networkAwareViewController setCachedDataAvailable:YES];

    if (!dataWasCached)
        [repoViewController scrollToTop];
}

- (void)failedToFetchInfoForRepo:(NSString *)repo
                        username:(NSString *)user
                           error:(NSError *)error
{
    if (![username isEqualToString:user] || ![repoName isEqualToString:repo])
        return;  // this is not the update we're waiting for

    if (!gitHubFailure) {
        gitHubFailure = YES;

        NSLog(@"Failed to retrieve info for repo: '%@' for user: '%@' "
            "error: '%@'.",
            repo,
            user,
            error);

        NSString * title =
            NSLocalizedString(@"github.repoupdate.failed.alert.title", @"");
        NSString * cancelTitle =
            NSLocalizedString(@"github.repoupdate.failed.alert.ok", @"");
        NSString * message = error.localizedDescription;

        UIAlertView * alertView =
            [[[UIAlertView alloc]
              initWithTitle:title
                    message:message
                   delegate:self
          cancelButtonTitle:cancelTitle
          otherButtonTitles:nil]
             autorelease];

        [alertView show];

        [networkAwareViewController
            setNoConnectionText:
            NSLocalizedString(@"nodata.noconnection.text", @"")];
        [networkAwareViewController setUpdatingState:kDisconnected];
    }
}

- (void)avatar:(UIImage *)avatar
    fetchedForEmailAddress:(NSString *)emailAddress
{
    [repoViewController updateWithAvatar:avatar forEmailAddress:emailAddress];
}

- (void)failedToFetchAvatarForEmailAddress:(NSString *)emailAddress
                                     error:(NSError *)error
{
    if (!avatarFailure) {
        avatarFailure = YES;
        
        NSLog(@"Failed to retrieve avatar for email address: '%@' error: '%@'.",
            emailAddress, error);

        NSString * title =
            NSLocalizedString(@"gravatar.repoupdate.failed.alert.title", @"");
        NSString * cancelTitle =
            NSLocalizedString(@"gravatar.repoupdate.failed.alert.ok", @"");
        NSString * message = error.localizedDescription;

        UIAlertView * alertView =
            [[[UIAlertView alloc]
              initWithTitle:title
                    message:message
                   delegate:self
          cancelButtonTitle:cancelTitle
          otherButtonTitles:nil]
             autorelease];

        [alertView show];
    }
}

#pragma mark RepoViewControllerDelegate implementation

- (void)userDidSelectCommit:(NSString *)commitKey
{
    [commitSelector user:username didSelectCommit:commitKey forRepo:repoName];
}

#pragma mark Helper methods

- (NSSet *)uniqueEmailsForCommits:(NSDictionary *)someCommits
{
    NSMutableSet * emails = [NSMutableSet setWithCapacity:someCommits.count];

    for (NSString * key in someCommits) {
        CommitInfo * commit = [someCommits objectForKey:key];
        NSString * email =
            [[commit.details objectForKey:@"committer"] objectForKey:@"email"];
        if (email)
            [emails addObject:email];
    }

    return emails;
}

- (NSDictionary *)cachedAvatarsForEmailAddresses:(NSSet *)emailAddresses
{
    NSMutableDictionary * avatars =
        [NSMutableDictionary dictionaryWithCapacity:emailAddresses.count];

    for (NSString * emailAddress in emailAddresses) {
        UIImage * avatar =
            [avatarCacheReader avatarForEmailAddress:emailAddress];
        if (avatar)
            [avatars setObject:avatar forKey:emailAddress];
    }

    return avatars;
}

- (void)fetchAvatarsForEmailAddresses:(NSSet *)emailAddresses
{
    for (NSString * emailAddress in emailAddresses)
        [[self gravatarService] fetchAvatarForEmailAddress:emailAddress];
}

- (BOOL)loadCachedData
{
    RepoInfo * cachedInfo =
        [self cachedRepoInfoForUsername:username repoName:repoName];
    [self setRepoInfo:cachedInfo];

    NSDictionary * cachedCommits = [self cachedCommitsForRepoInfo:cachedInfo];
    [self setCommits:cachedCommits];

    return cachedInfo && cachedCommits;
}

- (RepoInfo *)cachedRepoInfoForUsername:(NSString *)user
                               repoName:(NSString *)repo
{
    return [self isPrimaryUser:user] ?
        [repoCacheReader primaryUserRepoWithName:repo] :
        [repoCacheReader repoWithUsername:user repoName:repo];
}

- (NSDictionary *)cachedCommitsForRepoInfo:(RepoInfo *)info
{
    NSMutableDictionary * cachedCommits = [NSMutableDictionary dictionary];
    for (NSString * commitKey in info.commitKeys) {
        CommitInfo * commitInfo = [commitCacheReader commitWithKey:commitKey];
        if (commitInfo)
            [cachedCommits setObject:commitInfo forKey:commitKey];
        else {  // we need either all cached commits or no commits
            cachedCommits = nil;
            break;
        }
    }

    return cachedCommits.count == 0 ? nil : cachedCommits;
}

- (BOOL)isPrimaryUser:(NSString *)user
{
    return [user isEqualToString:logInStateReader.login];
}

#pragma mark Accessors

- (void)setUsername:(NSString *)user
{
    NSString * tmp = [user copy];
    [username release];
    username = tmp;
}

- (void)setRepoInfo:(RepoInfo *)info
{
    RepoInfo * tmp = [info copy];
    [repoInfo release];
    repoInfo = tmp;
}

- (void)setRepoName:(NSString *)name
{
    NSString * tmp = [name copy];
    [repoName release];
    repoName = tmp;
}

- (void)setCommits:(NSDictionary *)someCommits
{
    NSDictionary * tmp = [someCommits copy];
    [commits release];
    commits = tmp;
}

- (GravatarService *)gravatarService
{
    if (!gravatarService) {
        gravatarService =
            [[gravatarServiceFactory createGravatarService] retain];
        gravatarService.delegate = self;
    }

    return gravatarService;
}

@end
