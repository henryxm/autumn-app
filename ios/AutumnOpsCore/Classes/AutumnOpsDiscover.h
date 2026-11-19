#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface AutumnOpsDiscover : NSObject
+ (NSString *)discoverPath;
+ (NSString *)shareUrlForBase:(NSString *)baseUrl;
+ (nullable NSString *)tryParseBaseUrl:(NSString *)raw;
+ (nullable NSString *)tryParseBaseUrl:(NSString *)raw forceHttpBase:(BOOL)forceHttpBase;
@end
NS_ASSUME_NONNULL_END
