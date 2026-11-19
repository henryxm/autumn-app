#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface AutumnOpsValidateResult : NSObject
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic, readonly) BOOL ok;
+ (instancetype)ok;
+ (instancetype)fail:(NSString *)error;
@end
@interface AutumnOpsValidators : NSObject
+ (AutumnOpsValidateResult *)siteTitle:(NSString *)raw;
+ (AutumnOpsValidateResult *)siteEndpoint:(NSString *)raw;
+ (AutumnOpsValidateResult *)enrollSecret:(NSString *)raw;
+ (AutumnOpsValidateResult *)claimSecret:(NSString *)raw;
+ (AutumnOpsValidateResult *)clearToken:(NSString *)raw;
+ (AutumnOpsValidateResult *)sharePassphrase:(NSString *)raw;
+ (AutumnOpsValidateResult *)wrappedBlob:(NSString *)raw;
+ (AutumnOpsValidateResult *)ipOrCidr:(NSString *)raw;
@end
NS_ASSUME_NONNULL_END
