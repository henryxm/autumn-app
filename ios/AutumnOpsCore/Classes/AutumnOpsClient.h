#import <Foundation/Foundation.h>
#import "AutumnOpsModels.h"
#import "AutumnOpsStore.h"
#import "AutumnOpsProbeOutcome.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^AutumnOpsDictBlock)(NSDictionary * _Nullable data, NSError * _Nullable error);
typedef void (^AutumnOpsProbeBlock)(AutumnOpsProbeResult * _Nullable result, NSError * _Nullable error);
typedef void (^AutumnOpsProbeOutcomeBlock)(AutumnOpsProbeOutcome *outcome);
typedef void (^AutumnOpsEnrollBlock)(AutumnOpsEnrollResult * _Nullable result, NSError * _Nullable error);
typedef void (^AutumnOpsVoidBlock)(NSError * _Nullable error);
typedef void (^AutumnOpsIpPageBlock)(AutumnOpsIpPage * _Nullable page, NSError * _Nullable error);
typedef void (^AutumnOpsClaimBlock)(AutumnOpsClaimIssueResult * _Nullable result, NSError * _Nullable error);
typedef void (^AutumnOpsRevokeBlock)(AutumnOpsRevokeResult * _Nullable result, NSError * _Nullable error);
typedef void (^AutumnOpsStringBlock)(NSString * _Nullable value, NSError * _Nullable error);
typedef void (^AutumnOpsIntBlock)(NSInteger value, NSError * _Nullable error);

@interface AutumnOpsClient : NSObject
@property (nonatomic, copy, readonly) NSString *baseUrl;
@property (nonatomic, strong, readonly) AutumnOpsStore *store;
@property (nonatomic, copy) NSString *deviceLabel; // default ios

- (instancetype)initWithBaseUrl:(NSString *)baseUrl store:(AutumnOpsStore *)store;

- (void)probe:(AutumnOpsProbeBlock)completion;
- (void)probeOutcomeHasLocalCert:(BOOL)hasLocalCert completion:(AutumnOpsProbeOutcomeBlock)completion;
- (void)enrollWithSecret:(NSString *)secret completion:(AutumnOpsEnrollBlock)completion;
- (void)claimWithSecret:(NSString *)claimSecret completion:(AutumnOpsEnrollBlock)completion;
- (void)ensureSession:(AutumnOpsVoidBlock)completion;

- (void)adminIpListPage:(NSInteger)page limit:(NSInteger)limit completion:(AutumnOpsIpPageBlock)completion;
- (void)adminIpAdd:(nullable NSString *)ip claimCurrent:(BOOL)claimCurrent completion:(AutumnOpsDictBlock)completion;
- (void)adminIpRemove:(NSString *)ip clearToken:(nullable NSString *)clearToken completion:(AutumnOpsDictBlock)completion;
- (void)adminIpSetForbidden:(NSString *)ip forbidden:(BOOL)forbidden completion:(AutumnOpsDictBlock)completion;
- (void)currentIp:(AutumnOpsDictBlock)completion;

- (void)ipWhiteListPage:(NSInteger)page limit:(NSInteger)limit completion:(AutumnOpsIpPageBlock)completion;
- (void)ipWhiteAdd:(nullable NSString *)ip claimCurrent:(BOOL)claimCurrent completion:(AutumnOpsDictBlock)completion;
- (void)ipWhiteRemove:(NSString *)ip clearToken:(nullable NSString *)clearToken completion:(AutumnOpsDictBlock)completion;
- (void)ipWhiteSetForbidden:(NSString *)ip forbidden:(BOOL)forbidden completion:(AutumnOpsDictBlock)completion;

- (void)ipBlackListPage:(NSInteger)page limit:(NSInteger)limit completion:(AutumnOpsIpPageBlock)completion;
- (void)ipBlackAdd:(NSString *)ip completion:(AutumnOpsDictBlock)completion;
- (void)ipBlackRemove:(NSString *)ip completion:(AutumnOpsDictBlock)completion;
- (void)ipBlackSetAvailable:(NSString *)ip available:(NSInteger)available completion:(AutumnOpsDictBlock)completion;
- (void)ipBlackFirewallCount:(AutumnOpsIntBlock)completion;
- (void)ipBlackSetFirewallCount:(NSInteger)count completion:(AutumnOpsIntBlock)completion;

- (void)gateGet:(AutumnOpsDictBlock)completion;
- (void)runtimeSnapshot:(AutumnOpsDictBlock)completion;
- (void)gateVerifyClearToken:(NSString *)clearToken completion:(AutumnOpsDictBlock)completion;
- (void)gateSetClearToken:(NSString *)clearToken oldClearToken:(nullable NSString *)oldClearToken completion:(AutumnOpsDictBlock)completion;
- (void)gateSetAdminIpEnable:(BOOL)enable clearToken:(nullable NSString *)clearToken completion:(AutumnOpsDictBlock)completion;
- (void)gateSetDiscoverEnabled:(BOOL)enable completion:(AutumnOpsDictBlock)completion;

- (void)certList:(AutumnOpsDictBlock)completion;
- (void)certIssueWithLabel:(NSString *)label completion:(AutumnOpsClaimBlock)completion;
- (void)certRevoke:(NSString *)certId completion:(AutumnOpsRevokeBlock)completion;

- (nullable AutumnOpsCredentialBundle *)currentBundle:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)exportWrappedWithPassphrase:(NSString *)passphrase error:(NSError * _Nullable * _Nullable)error;
- (BOOL)importWrapped:(NSString *)wrappedB64 passphrase:(NSString *)passphrase error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
