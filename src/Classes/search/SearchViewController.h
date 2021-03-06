//
//  Copyright 2009 High Order Bit, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SearchServiceDelegate.h"
#import "SearchViewControllerDelegate.h"

@interface SearchViewController :
    UIViewController
    <UITableViewDelegate, UISearchBarDelegate, SearchServiceDelegate>
{
    IBOutlet NSObject<SearchViewControllerDelegate> * delegate;
    
    IBOutlet UITableView * tableView;
    IBOutlet UISearchBar * searchBar;
    IBOutlet UIActivityIndicatorView * activityIndicator;
    IBOutlet UILabel * loadingLabel;
    NSObject<SearchService> * searchService;
    
    NSDictionary * searchResults;
    NSMutableDictionary * nonZeroSearchResults;
    
    NSString * title;
    BOOL canceled;
}

@property (nonatomic, retain) NSObject<SearchViewControllerDelegate> * delegate;
@property (nonatomic, retain) NSDictionary * searchResults;

- (id)initWithSearchService:(NSObject<SearchService> *)aSearchService;

@end
