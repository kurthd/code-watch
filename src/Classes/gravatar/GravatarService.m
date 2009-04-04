//
//  Copyright High Order Bit, Inc. 2009. All rights reserved.
//

#import "GravatarService.h"
#import "Gravatar.h"

@implementation GravatarService

@synthesize delegate;

- (void)dealloc
{
    [delegate release];
    [avatarCacheSetter release];
    [gravatar release];
    [super dealloc];
}

#pragma mark Initialization

- (id)initWithGravatarBaseUrlString:(NSString *)baseUrl
                  avatarCacheSetter:(id<AvatarCacheSetter>)anAvatarCacheSetter
{
    if (self = [super init]) {
        gravatar = [[Gravatar alloc] initWithBaseUrlString:baseUrl
                                                  delegate:self];
        avatarCacheSetter = [anAvatarCacheSetter retain];
    }

    return self;
}

#pragma mark Fetching avatars

- (void)fetchAvatarForEmailAddress:(NSString *)emailAddress
{
    [gravatar fetchAvatarForEmailAddress:emailAddress];
}

#pragma mark GravatarDelegate implementation

- (void)avatar:(UIImage *)avatar
    fetchedForEmailAddress:(NSString *)emailAddress
{
    [avatarCacheSetter setAvatar:avatar forEmailAddress:emailAddress];
    [delegate avatar:avatar fetchedForEmailAddress:emailAddress];
}

- (void)failedToFetchAvatarForEmailAddress:(NSString *)emailAddress
    error:(NSError *)error
{
    [delegate failedToFetchAvatarForEmailAddress:emailAddress error:error];
}

@end
