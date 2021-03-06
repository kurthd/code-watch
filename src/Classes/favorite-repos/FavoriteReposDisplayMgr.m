//
//  Copyright 2009 High Order Bit, Inc. All rights reserved.
//

#import "FavoriteReposDisplayMgr.h"

@implementation FavoriteReposDisplayMgr

- (void)dealloc
{
    [viewController release];
    [favoriteReposStateReader release];
    [favoriteReposStateSetter release];
    [repoSelector release];
    [super dealloc];
}

- (id)initWithViewController:(FavoriteReposViewController *)aViewController
    stateReader:(NSObject<FavoriteReposStateReader> *)aFavoriteReposStateReader
    stateSetter:(NSObject<FavoriteReposStateSetter> *)aFavoriteReposStateSetter
    repoSelector:(NSObject<RepoSelector> *)aRepoSelector
{
    if (self = [super init]) {
        viewController = [aViewController retain];
        favoriteReposStateReader = [aFavoriteReposStateReader retain];
        favoriteReposStateSetter = [aFavoriteReposStateSetter retain];
        repoSelector = [aRepoSelector retain];
    }
    
    return self;
}

#pragma mark FavoriteReposViewControllerDelegate implementation

- (void)viewWillAppear
{
    [viewController setRepoKeys:favoriteReposStateReader.favoriteRepoKeys];
}

- (void)removedRepoKey:(RepoKey *)repoKey;
{
    [favoriteReposStateSetter removeFavoriteRepoKey:repoKey];
    [viewController setRepoKeys:favoriteReposStateReader.favoriteRepoKeys];
}

- (void)setRepoKeySortOrder:(NSArray *)sortedRepoKeys
{
    for (RepoKey * repoKey in sortedRepoKeys) {
        [favoriteReposStateSetter removeFavoriteRepoKey:repoKey];
        [favoriteReposStateSetter addFavoriteRepoKey:repoKey];
    }
}

- (void)selectedRepoKey:(RepoKey *)repoKey
{
    [repoSelector user:repoKey.username didSelectRepo:repoKey.repoName];
}

@end
