//
//  Copyright High Order Bit, Inc. 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (NSDataAdditions)

+ (NSString *)stringWithUTF8EncodedData:(NSData *)data;
+ (NSString *)stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding;

@end
