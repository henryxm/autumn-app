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
/// 管理/白/黑名单 IP；rejectPolicyBlackIp 时拒绝 0.0.0.0（对齐 Flutter wallIp）。
+ (AutumnOpsValidateResult *)wallIp:(NSString *)raw rejectPolicyBlackIp:(BOOL)rejectPolicyBlackIp;
+ (AutumnOpsValidateResult *)deviceLabel:(NSString *)raw;
@end
NS_ASSUME_NONNULL_END
