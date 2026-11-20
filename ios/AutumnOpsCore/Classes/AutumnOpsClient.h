#import <Foundation/Foundation.h>
#import "AutumnOpsModels.h"
#import "AutumnOpsStore.h"
#import "AutumnOpsProbeOutcome.h"
#import "AutumnOpsRuntimeModels.h"

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
typedef void (^AutumnOpsRuntimeSnapshotBlock)(AutumnOpsRuntimeSnapshot * _Nullable snap, NSError * _Nullable error);

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

- (void)shieldListPage:(NSInteger)page limit:(NSInteger)limit completion:(AutumnOpsDictBlock)completion;
- (void)shieldSaveUri:(NSString *)uri enable:(BOOL)enable autoValue:(NSInteger)autoValue completion:(AutumnOpsDictBlock)completion;
- (void)shieldUpdateId:(NSInteger)sid uri:(nullable NSString *)uri enable:(nullable NSNumber *)enable autoValue:(nullable NSNumber *)autoValue completion:(AutumnOpsDictBlock)completion;
- (void)shieldDeleteIds:(NSArray<NSNumber *> *)ids completion:(AutumnOpsDictBlock)completion;
- (void)shieldStatus:(AutumnOpsDictBlock)completion;
- (void)shieldSetAttack:(BOOL)attack completion:(AutumnOpsDictBlock)completion;
- (void)shieldSetPrint:(BOOL)print completion:(AutumnOpsDictBlock)completion;
- (void)shieldSetEnable:(BOOL)enable completion:(AutumnOpsDictBlock)completion;

- (void)jumpListPage:(NSInteger)page limit:(NSInteger)limit completion:(AutumnOpsDictBlock)completion;
- (void)jumpSaveHost:(NSString *)host uri:(NSString *)uri url:(NSString *)url enable:(BOOL)enable completion:(AutumnOpsDictBlock)completion;
- (void)jumpUpdateId:(NSInteger)jid host:(nullable NSString *)host uri:(nullable NSString *)uri url:(nullable NSString *)url enable:(nullable NSNumber *)enable completion:(AutumnOpsDictBlock)completion;
- (void)jumpDeleteIds:(NSArray<NSNumber *> *)ids completion:(AutumnOpsDictBlock)completion;

- (void)gateGet:(AutumnOpsDictBlock)completion;
- (void)runtimeSnapshot:(AutumnOpsDictBlock)completion;
/// ensureSession → snapshot → 强类型模型（对齐 Flutter loadSnapshot）。
- (void)runtimeSnapshotModel:(AutumnOpsRuntimeSnapshotBlock)completion;
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
