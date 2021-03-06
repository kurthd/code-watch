//
//  Copyright High Order Bit, Inc. 2009. All rights reserved.
//

#import "GitHubService.h"

#import "GitHub.h"

#import "UIApplication+NetworkActivityIndicatorAdditions.h"

@interface GitHubService (Private)

- (void)setPrimaryUser:(NSString *)username token:(NSString *)token;
- (void)cacheUserInfo:(UserInfo *)info forUsername:(NSString *)username;
- (void)cacheRepos:(NSDictionary *)repos forUsername:(NSString *)username;
- (void)cacheRepoInfo:(RepoInfo *)repoInfo forUsername:(NSString *)username
    repoName:(NSString *)repoName;
- (void)cacheCommits:(NSDictionary *)commits forUsername:(NSString *)username
    repo:(NSString *)repoName;
- (void)cacheCommit:(CommitInfo *)commit forKey:(NSString *)commitKey;

+ (UserInfo *)extractUserInfo:(NSDictionary *)gitHubInfo;
+ (NSDictionary *)extractUserDetails:(NSDictionary *)gitHubInfo;
+ (NSArray *)extractRepoKeys:(NSDictionary *)gitHubInfo;
+ (NSDictionary *)extractRepoInfos:(NSDictionary *)gitHubInfo;
+ (NSArray *)extractCommitKeys:(NSDictionary *)gitHubInfo;
+ (NSDictionary *)extractCommitInfos:(NSDictionary *)gitHubInfo;
+ (NSDictionary *)extractChangesets:(NSDictionary *)gitHubInfo;

- (BOOL)isAttemptingLogIn;
- (BOOL)isAttemptingLogInForUsername:(NSString *)username;
- (void)startingLogInAttemptForUsername:(NSString *)username;
- (void)logInAttemptFinished;
- (void)setUsernameForLogInAttempt:(NSString *)s;

- (RepoInfo *)repoInfoForUser:username repo:(NSString *)repo;
- (BOOL)isPrimaryUser:(NSString *)username;

@end

@implementation GitHubService

@synthesize delegate;

- (void)dealloc
{
    [configReader release];

    [logInStateReader release];
    [userCacheSetter release];
    [userCacheReader release];
    [repoCacheSetter release];
    [repoCacheReader release];
    [userNetworkCacheSetter release];

    [usernameForLogInAttempt release];

    [gitHub release];

    [super dealloc];
}

#pragma mark Initialization

- (id)initWithConfigReader:(NSObject<ConfigReader> *)aConfigReader
    logInState:(LogInState *)logInState
    userCache:(UserCache*)userCache repoCache:(RepoCache *)repoCache
    commitCache:(CommitCache *)commitCache
    userNetworkCache:(UserNetworkCache *)aUserNetworkCache
{
    if (self = [super init]) {
        configReader = [aConfigReader retain];
        logInStateReader = [logInState retain];
        logInStateSetter = [logInState retain];
        userCacheReader = [userCache retain];
        userCacheSetter = [userCache retain];
        repoCacheReader = [repoCache retain];
        repoCacheSetter = [repoCache retain];
        commitCacheReader = [commitCache retain];
        commitCacheSetter = [commitCache retain];
        userNetworkCacheSetter = [aUserNetworkCache retain];

        [self awakeFromNib];
    }
    
    return self;
}

- (void)awakeFromNib
{
    NSString * gitHubUrl = [configReader valueForKey:@"GitHubApiBaseUrl"];
    NSURL * gitHubApiBaseUrl = [NSURL URLWithString:gitHubUrl];

    GitHubApiFormat apiFormat =
        [[configReader valueForKey:@"GitHubApiFormat"] intValue];

    gitHub = [[GitHub alloc] initWithBaseUrl:gitHubApiBaseUrl
                                      format:apiFormat
                                    delegate:self];
}

#pragma mark Logging in

- (void)logIn:(NSString *)username
{
    [self logIn:username token:nil];
}

- (void)logIn:(NSString *)username token:(NSString *)token
{
    [[UIApplication sharedApplication] networkActivityIsStarting];

    if (![self isAttemptingLogIn]) {
        [self startingLogInAttemptForUsername:username];
        [gitHub fetchInfoForUsername:username token:token];
    }
}

#pragma mark Fetching user info

- (void)fetchInfoForUsername:(NSString *)username
{
    [[UIApplication sharedApplication] networkActivityIsStarting];

    NSString * token = nil;
    if ([self isPrimaryUser:username])
        token = logInStateReader.token;

    [gitHub fetchInfoForUsername:username token:token];
}

#pragma mark Fetching repo info

- (void)fetchInfoForRepo:(NSString *)repo username:(NSString *)username
{
    [[UIApplication sharedApplication] networkActivityIsStarting];

    NSString * token = nil;
    if ([self isPrimaryUser:username])
        token = logInStateReader.token;

    [gitHub fetchInfoForRepo:repo username:username token:token];
}

#pragma mark Fetching commit info

- (void)fetchInfoForCommit:(NSString *)commitKey
                      repo:(NSString *)repo
                  username:(NSString *)username
{
    [[UIApplication sharedApplication] networkActivityIsStarting];

    NSString * token = nil;
    if ([self isPrimaryUser:username])
        token = logInStateReader.token;

    [gitHub
        fetchInfoForCommit:commitKey repo:repo username:username token:token];
}

#pragma mark Fetching followers

- (void)fetchFollowingForUsername:(NSString *)username
{
    [[UIApplication sharedApplication] networkActivityIsStarting];

    [gitHub fetchFollowingForUsername:username];
}

- (void)fetchFollowersForUsername:(NSString *)username
{
    [[UIApplication sharedApplication] networkActivityIsStarting];

    [gitHub fetchFollowersForUsername:username];
}

- (void)followUsername:(NSString *)followee
{
    [[UIApplication sharedApplication] networkActivityIsStarting];

    [gitHub followUsername:followee follower:logInStateReader.login
        token:logInStateReader.token];
}

- (void)unfollowUsername:(NSString *)followee
{
    [[UIApplication sharedApplication] networkActivityIsStarting];

    [gitHub unfollowUsername:followee follower:logInStateReader.login
        token:logInStateReader.token];
}

#pragma mark Searching GitHub

- (void)searchUsers:(NSString *)searchString
{
    [[UIApplication sharedApplication] networkActivityIsStarting];

    [gitHub searchUsers:searchString];
}

- (void)searchRepos:(NSString *)searchString
{
    [[UIApplication sharedApplication] networkActivityIsStarting];

    [gitHub searchRepos:searchString];
}

#pragma mark GitHubDelegate implementation

- (void)userInfo:(NSDictionary *)info fetchedForUsername:(NSString *)username
    token:(NSString *)token
{
    UserInfo * ui = [[self class] extractUserInfo:info];
    NSDictionary * repos = [[self class] extractRepoInfos:info];

    if ([self isAttemptingLogInForUsername:username]) {
        [self setPrimaryUser:username token:token];
        [self logInAttemptFinished];

        SEL selector = @selector(logInSucceeded:);
        if ([delegate respondsToSelector:selector])
            [delegate logInSucceeded:username];
    }

    [self cacheUserInfo:ui forUsername:username];
    [self cacheRepos:repos forUsername:username];

    SEL selector = @selector(userInfo:repoInfos:fetchedForUsername:);
    if ([delegate respondsToSelector:selector])
        [delegate userInfo:ui repoInfos:repos fetchedForUsername:username];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)failedToFetchInfoForUsername:(NSString *)username error:(NSError *)error
{
    if ([self isAttemptingLogInForUsername:username]) {
        [self logInAttemptFinished];

        SEL selector = @selector(logInFailed:error:);
        if ([delegate respondsToSelector:selector])
            [delegate logInFailed:username error:error];
    } else {
        SEL selector = @selector(failedToFetchInfoForUsername:error:);
        if ([delegate respondsToSelector:selector])
            [delegate failedToFetchInfoForUsername:username error:error];
    }

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)commits:(NSDictionary *)commits fetchedForRepo:(NSString *)repo
    username:(NSString *)username token:(NSString *)token
{
    RepoInfo * repoInfo = [self repoInfoForUser:username repo:repo];
    NSArray * commitKeys = [[self class] extractCommitKeys:commits];
    NSDictionary * commitInfos = [[self class] extractCommitInfos:commits];
    repoInfo = [[[RepoInfo alloc] initWithDetails:repoInfo.details
                                       commitKeys:commitKeys] autorelease];

    [self cacheRepoInfo:repoInfo forUsername:username repoName:repo];
    [self cacheCommits:commitInfos forUsername:username repo:repo];

    SEL selector = @selector(commits:fetchedForRepo:username:);
    if ([delegate respondsToSelector:selector])
        [delegate commits:commitInfos fetchedForRepo:repo username:username];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)failedToFetchInfoForRepo:(NSString *)repo
                        username:(NSString *)username
                           error:(NSError *)error
{
    SEL selector = @selector(failedToFetchInfoForRepo:username:error:);
    if ([delegate respondsToSelector:selector])
        [delegate failedToFetchInfoForRepo:repo username:username error:error];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)commitDetails:(NSDictionary *)details
    fetchedForCommit:(NSString *)commitKey repo:(NSString *)repo
    username:(NSString *)username token:(NSString *)token
{
    CommitInfo * commitInfo = [commitCacheReader commitWithKey:commitKey];
    NSDictionary * changesets = [[self class] extractChangesets:details];

    commitInfo = [[[CommitInfo alloc] initWithDetails:commitInfo.details
       changesets:changesets] autorelease];

    [self cacheCommit:commitInfo forKey:commitKey];

    SEL selector = @selector(commitInfo:fetchedForCommit:repo:username:);
    if ([delegate respondsToSelector:selector])
        [delegate commitInfo:commitInfo fetchedForCommit:commitKey
            repo:repo username:username];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)failedToFetchInfoForCommit:(NSString *)commit repo:(NSString *)repo
    username:(NSString *)username token:(NSString *)token error:(NSError *)error
{
    SEL selector = @selector(failedToFetchInfoForCommit:repo:username:error:);
    if ([delegate respondsToSelector:selector])
        [delegate failedToFetchInfoForCommit:commit repo:repo username:username
            error:error];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)following:(NSDictionary *)results
    fetchedForUsername:(NSString *)username
{
    NSArray * following = [results objectForKey:@"users"];

    if ([self isPrimaryUser:username])
        [userNetworkCacheSetter setFollowingForPrimaryUser:following];

    SEL sel = @selector(following:fetchedForUsername:);
    if ([delegate respondsToSelector:sel])
        [delegate following:following fetchedForUsername:username];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)failedToFetchFollowingForUsername:(NSString *)username
    error:(NSError *)error
{
    SEL sel = @selector(failedToFetchFollowingForUsername:error:);
    if ([delegate respondsToSelector:sel])
        [delegate failedToFetchFollowingForUsername:username error:error];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)followers:(NSDictionary *)results
    fetchedForUsername:(NSString *)username
{
    //
    // TODO: Write to user network cache.
    //

    NSArray * followers = [results objectForKey:@"users"];

    SEL sel = @selector(followers:fetchedForUsername:);
    if ([delegate respondsToSelector:sel])
        [delegate followers:followers fetchedForUsername:username];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)failedToFetchFollowersForUsername:(NSString *)username
    error:(NSError *)error
{
    SEL sel = @selector(failedToFetchFollowersForUsername:error:);
    if ([delegate respondsToSelector:sel])
        [delegate failedToFetchFollowersForUsername:username error:error];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)username:(NSString *)follower isFollowing:(NSString *)followee
    token:(NSString *)token
{
    //
    // TODO: Write to user network cache.
    //

    SEL sel = @selector(username:isFollowing:);
    if ([delegate respondsToSelector:sel])
        [delegate username:follower isFollowing:followee];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)failedToFollowUsername:(NSString *)followee
    follower:(NSString *)follower token:(NSString *)token
    error:(NSError *)error
{
    SEL sel = @selector(failedToFollowUsername:follower:error:);
    if ([delegate respondsToSelector:sel])
        [delegate
            failedToFollowUsername:followee follower:follower error:error];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)username:(NSString *)follower didUnfollow:(NSString *)followee
    token:(NSString *)token
{
    SEL sel = @selector(username:didUnfollow:);
    if ([delegate respondsToSelector:sel])
        [delegate username:follower didUnfollow:followee];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)failedToUnfollowUsername:(NSString *)followee
    follower:(NSString *)follower token:(NSString *)token
    error:(NSError *)error
{
    SEL sel = @selector(failedToUnfollowUsername:follower:error:);
    if ([delegate respondsToSelector:sel])
        [delegate
            failedToUnfollowUsername:followee follower:follower error:error];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)userSearchResults:(NSDictionary *)results
    foundForSearchString:(NSString *)searchString
{
    NSArray * users = [results objectForKey:@"users"];

    SEL selector = @selector(users:foundForSearchString:);
    if ([delegate respondsToSelector:selector])
        [delegate users:users foundForSearchString:searchString];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)failedToSearchUsersForString:(NSString *)searchString
    error:(NSError *)error
{
    SEL selector = @selector(failedToSearchUsersForString:error:);
    if ([delegate respondsToSelector:selector])
        [delegate failedToSearchUsersForString:searchString error:error];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)repoSearchResults:(NSDictionary *)results
    foundForSearchString:(NSString *)searchString
{
    NSArray * repos = [results objectForKey:@"repositories"];

    SEL selector = @selector(repos:foundForSearchString:);
    if ([delegate respondsToSelector:selector])
        [delegate repos:repos foundForSearchString:searchString];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

- (void)failedToSearchReposForString:(NSString *)searchString
    error:(NSError *)error
{
    SEL selector = @selector(failedToSearchReposForString:error:);
    if ([delegate respondsToSelector:selector])
        [delegate failedToSearchReposForString:searchString error:error];

    [[UIApplication sharedApplication] networkActivityDidFinish];
}

#pragma mark Persisting received data

- (void)setPrimaryUser:(NSString *)username token:(NSString *)token
{
    [logInStateSetter setLogin:username token:token prompt:NO];
}

- (void)cacheUserInfo:(UserInfo *)info forUsername:(NSString *)username
{
    if ([self isPrimaryUser:username])
        [userCacheSetter setPrimaryUser:info];
    else
        [userCacheSetter addRecentlyViewedUser:info withUsername:username];
}

- (void)cacheRepos:(NSDictionary *)repos forUsername:(NSString *)username
{
    UserInfo * userInfo = [self isPrimaryUser:username] ?
        userCacheReader.primaryUser :
        [userCacheReader userWithUsername:username];

    for (NSString * repoKey in userInfo.repoKeys)
        [self cacheRepoInfo:[repos objectForKey:repoKey] forUsername:username
            repoName:repoKey];
}

- (void)cacheRepoInfo:(RepoInfo *)repoInfo forUsername:(NSString *)username
    repoName:(NSString *)repoName
{
    RepoInfo * cachedInfo = nil;
    if ([self isPrimaryUser:username])
        cachedInfo = [repoCacheReader primaryUserRepoWithName:repoName];
    else
        cachedInfo =
            [repoCacheReader repoWithUsername:username repoName:repoName];

    if (cachedInfo) {
        NSDictionary * details = nil;
        NSArray * commitKeys = nil;

        details = repoInfo.details ? repoInfo.details : cachedInfo.details;
        commitKeys =
            repoInfo.commitKeys ? repoInfo.commitKeys : cachedInfo.commitKeys;

        repoInfo = [[[RepoInfo alloc]
            initWithDetails:details commitKeys:commitKeys] autorelease];
    }

    if ([self isPrimaryUser:username])
        [repoCacheSetter setPrimaryUserRepo:repoInfo forRepoName:repoName];
    else
        [repoCacheSetter addRecentlyViewedRepo:repoInfo
                                  withRepoName:repoName
                                      username:username];
}

- (void)cacheCommits:(NSDictionary *)commits forUsername:(NSString *)username
    repo:(NSString *)repoName
{
    RepoInfo * repoInfo = nil;
    if ([self isPrimaryUser:username])
        repoInfo = [repoCacheReader primaryUserRepoWithName:repoName];
    else
        repoInfo =
            [repoCacheReader repoWithUsername:username repoName:repoName];

    for (NSString * commitKey in repoInfo.commitKeys) {
        CommitInfo * commit = [commits objectForKey:commitKey];
        [self cacheCommit:commit forKey:commitKey];
    }
}

- (void)cacheCommit:(CommitInfo *)commit forKey:(NSString *)commitKey
{
    CommitInfo * cached = [commitCacheReader commitWithKey:commitKey];
    if (!(cached.details && cached.changesets))
        // only cache if we don't already have a complete existing copy
        // since commits don't change
        [commitCacheSetter setCommit:commit forKey:commitKey];
}

#pragma mark Parsing received data

+ (UserInfo *)extractUserInfo:(NSDictionary *)gitHubInfo
{
    NSDictionary * details = [[self class] extractUserDetails:gitHubInfo];
    NSArray * keys = [[self class] extractRepoKeys:gitHubInfo];

    return
        [[[UserInfo alloc] initWithDetails:details repoKeys:keys] autorelease];
}

+ (NSDictionary *)extractUserDetails:(NSDictionary *)gitHubInfo
{
    NSMutableDictionary * info =
        [[[gitHubInfo objectForKey:@"user"] mutableCopy] autorelease];

    [info removeObjectForKey:@"login"];
    [info removeObjectForKey:@"repositories"];

    return info;
}

+ (NSArray *)extractRepoKeys:(NSDictionary *)gitHubInfo
{
    NSArray * repos =
        [[gitHubInfo objectForKey:@"user"] objectForKey:@"repositories"];
    NSMutableArray * repoNames =
        [NSMutableArray arrayWithCapacity:repos.count];
    for (NSDictionary * repo in repos)
        [repoNames addObject:[repo objectForKey:@"name"]];

    return repoNames;
}

+ (NSDictionary *)extractRepoInfos:(NSDictionary *)gitHubInfo
{
    NSArray * repos =
        [[gitHubInfo objectForKey:@"user"] objectForKey:@"repositories"];

    NSMutableDictionary * repoInfos =
        [NSMutableDictionary dictionaryWithCapacity:repos.count];
    for (NSDictionary * repo in repos) {
        NSString * repoName = [repo objectForKey:@"name"];

        NSMutableDictionary * details = [[repo mutableCopy] autorelease];
        [details removeObjectForKey:@"name"];

        RepoInfo * repoInfo = [[RepoInfo alloc] initWithDetails:details];
        [repoInfos setObject:repoInfo forKey:repoName];
        [repoInfo release];
    }

    return repoInfos;
}

+ (NSArray *)extractCommitKeys:(NSDictionary *)gitHubInfo
{
    NSArray * commits = [gitHubInfo objectForKey:@"commits"];

    NSMutableArray * commitKeys =
        [NSMutableArray arrayWithCapacity:commits.count];
    for (NSDictionary * commit in commits) {
        NSString * key = [commit objectForKey:@"id"];
        [commitKeys addObject:key];
    }

    return commitKeys;
}

+ (NSDictionary *)extractCommitInfos:(NSDictionary *)gitHubInfo
{
    NSMutableDictionary * commitInfos = [NSMutableDictionary dictionary];

    for (NSDictionary * commit in [gitHubInfo objectForKey:@"commits"]) {
        NSMutableDictionary * details = [[commit mutableCopy] autorelease];
        NSString * commitKey = [details objectForKey:@"id"];

        [details removeObjectForKey:@"id"];

        CommitInfo * commitInfo = [[CommitInfo alloc] initWithDetails:details];
        [commitInfos setObject:commitInfo forKey:commitKey];
        [commitInfo release];
    }

    return commitInfos;
}

+ (NSDictionary *)extractChangesets:(NSDictionary *)gitHubInfo
{
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];

    NSDictionary * details = [gitHubInfo objectForKey:@"commit"];

    [dict setObject:[details objectForKey:@"added"] forKey:@"added"];
    [dict setObject:[details objectForKey:@"removed"] forKey:@"removed"];
    [dict setObject:[details objectForKey:@"modified"] forKey:@"modified"];

    return dict;
}

#pragma mark Tracking log in attempts

- (BOOL)isAttemptingLogIn
{
    return !!usernameForLogInAttempt;
}

- (BOOL)isAttemptingLogInForUsername:(NSString *)username
{
    return
        [self isAttemptingLogIn] &&
        [username isEqualToString:usernameForLogInAttempt];
}

- (void)startingLogInAttemptForUsername:(NSString *)username
{
    [self setUsernameForLogInAttempt:username];
}

- (void)logInAttemptFinished
{
    [self setUsernameForLogInAttempt:nil];
}

#pragma mark Miscellaneous helpers

- (RepoInfo *)repoInfoForUser:username repo:(NSString *)repo
{
    return [self isPrimaryUser:username] ?
        [repoCacheReader primaryUserRepoWithName:repo] :
        [repoCacheReader repoWithUsername:username repoName:repo];
}

- (BOOL)isPrimaryUser:(NSString *)username
{
    return [username isEqualToString:logInStateReader.login];
}

#pragma mark Accessors

- (void)setUsernameForLogInAttempt:(NSString *)s
{
    NSString * tmp = [s copy];
    [usernameForLogInAttempt release];
    usernameForLogInAttempt = tmp;
}

@end
