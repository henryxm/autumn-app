#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface AutumnOpsPayload : NSObject
@property (nonatomic, copy) NSString *wrapped;
@property (nonatomic, copy, nullable) NSString *baseUrl;
@property (nonatomic, copy, nullable) NSString *siteId;
@property (nonatomic, copy, nullable) NSString *certId;
@property (nonatomic, copy, nullable) NSString *serverFingerprint;
@property (nonatomic, strong, nullable) NSNumber *createdAtMs;
+ (NSString *)kind;
+ (NSString *)messageType;
+ (NSString *)fileExtension;
+ (NSDictionary *)toMessageMapWithWrapped:(NSString *)wrapped
                                  baseUrl:(nullable NSString *)baseUrl
                                   siteId:(nullable NSString *)siteId
                                   certId:(nullable NSString *)certId
                       serverFingerprint:(nullable NSString *)serverFingerprint
                             createdAtMs:(nullable NSNumber *)createdAtMs;
- (NSDictionary *)toMap;
@end
@interface AutumnOpsParseResult : NSObject
@property (nonatomic, strong, nullable) AutumnOpsPayload *payload;
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic, readonly) BOOL ok;
+ (instancetype)ok:(AutumnOpsPayload *)payload;
+ (instancetype)fail:(NSString *)error;
+ (AutumnOpsParseResult *)fromMessageMap:(NSDictionary *)map;
+ (AutumnOpsParseResult *)parse:(NSString *)raw;
@end
NS_ASSUME_NONNULL_END
