#import <Foundation/Foundation.h>
#import "AutumnOpsStore.h"
NS_ASSUME_NONNULL_BEGIN

@interface AutumnOpsSiteEntry : NSObject
@property (nonatomic, copy) NSString *id;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *baseUrl;
@property (nonatomic, copy, nullable) NSString *siteId;
@property (nonatomic, copy, nullable) NSString *certId;
@property (nonatomic, copy, nullable) NSString *serverFingerprint;
@property (nonatomic) BOOL enrolled;
- (NSDictionary *)toJSON;
+ (instancetype)fromJSON:(NSDictionary *)json;
+ (NSString *)normalizeBaseUrl:(NSString *)u;
/// 凭证目录键：与 Flutter OpsSiteEntry.siteKeyFromBaseUrl 一致（非 entry.id）
+ (NSString *)siteKeyFromBaseUrl:(NSString *)baseUrl;
@end

@interface AutumnOpsSiteStore : NSObject
- (instancetype)initWithRootDirectory:(NSURL *)rootDir;
- (NSArray<AutumnOpsSiteEntry *> *)listSites:(NSError * _Nullable * _Nullable)error;
- (BOOL)saveSites:(NSArray<AutumnOpsSiteEntry *> *)sites error:(NSError * _Nullable * _Nullable)error;

/// SSOT：凭证始终按 baseUrl 派生目录（对齐 Flutter credentialStoreFor）
- (AutumnOpsStore *)credentialStoreForSite:(AutumnOpsSiteEntry *)site;
- (AutumnOpsStore *)credentialStoreForBaseUrl:(NSString *)baseUrl;

- (BOOL)upsertSite:(AutumnOpsSiteEntry *)site error:(NSError * _Nullable * _Nullable)error;
- (BOOL)removeSiteId:(NSString *)siteEntryId error:(NSError * _Nullable * _Nullable)error;
- (nullable AutumnOpsSiteEntry *)findByCertId:(NSString *)certId;
- (nullable AutumnOpsSiteEntry *)findByBaseUrl:(NSString *)baseUrl;
- (BOOL)hasLocalCredential:(AutumnOpsSiteEntry *)site;

+ (NSURL *)defaultRootDirectory;
@end

NS_ASSUME_NONNULL_END
