#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutumnOpsProbeResult : NSObject
@property (nonatomic) BOOL autumn;
@property (nonatomic, copy) NSString *opsCert;
@property (nonatomic) BOOL adminIpEnable;
@property (nonatomic) BOOL enrollAvailable;
@property (nonatomic) BOOL discoverEnabled;
@property (nonatomic, copy, nullable) NSString *siteId;
@property (nonatomic, copy, nullable) NSString *serverFingerprint;
@property (nonatomic, strong, nullable) NSNumber *protocolVersion;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsEnrollResult : NSObject
@property (nonatomic, copy) NSString *certId;
@property (nonatomic, copy) NSString *siteId;
@property (nonatomic, copy) NSString *serverPublicKey;
@property (nonatomic, copy, nullable) NSString *serverFingerprint;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsClaimIssueResult : NSObject
@property (nonatomic, copy) NSString *claimId;
@property (nonatomic, copy) NSString *claimSecret;
@property (nonatomic) NSInteger expiresAt;
@property (nonatomic, copy, nullable) NSString *siteId;
@property (nonatomic, copy, nullable) NSString *serverFingerprint;
@property (nonatomic, copy, nullable) NSString *label;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRevokeResult : NSObject
@property (nonatomic) BOOL success;
@property (nonatomic) BOOL lastCert;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsIpRow : NSObject
@property (nonatomic, copy) NSString *ip;
@property (nonatomic, copy, nullable) NSString *tag;
@property (nonatomic, copy, nullable) NSString *descText;
@property (nonatomic, strong, nullable) NSNumber *forbidden;
@property (nonatomic, strong, nullable) NSNumber *available;
@property (nonatomic, strong, nullable) NSNumber *createTimeMs;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsIpPage : NSObject
@property (nonatomic) NSInteger count;
@property (nonatomic) NSInteger page;
@property (nonatomic) NSInteger limit;
@property (nonatomic) BOOL hasMore;
@property (nonatomic, copy) NSArray<AutumnOpsIpRow *> *list;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsCredentialBundle : NSObject
@property (nonatomic, copy) NSString *siteId;
@property (nonatomic, copy) NSString *certId;
@property (nonatomic, copy) NSString *baseUrl;
@property (nonatomic, copy) NSString *clientPrivateKeyPem;
@property (nonatomic, copy) NSString *clientPublicKeyPem;
@property (nonatomic, copy) NSString *serverPublicKey;
@property (nonatomic, copy, nullable) NSString *serverFingerprint;
@property (nonatomic, copy, nullable) NSString *label;
- (NSDictionary *)toJSON;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

NS_ASSUME_NONNULL_END
