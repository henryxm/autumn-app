#import <UIKit/UIKit.h>
@class AutumnOpsClient;
@class AutumnOpsIpPage;
@class AutumnOpsIpRow;
@class AutumnOpsIpUpsertResult;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AutumnOpsIpStatusMode) {
  AutumnOpsIpStatusModeForbidden = 0, // 管理/白：forbidden 0 启用
  AutumnOpsIpStatusModeAvailable = 1, // 黑：available 0 生效
};

/// 启停过滤：服务端 `forbidden`/`available` 等值筛选（对齐 Flutter OpsIpActiveFilter）。
typedef NS_ENUM(NSInteger, AutumnOpsIpActiveFilter) {
  AutumnOpsIpActiveFilterAll = 0,
  AutumnOpsIpActiveFilterActive = 1,
  AutumnOpsIpActiveFilterInactive = 2,
};

typedef void (^AutumnOpsIpPanelToast)(NSString *message);
typedef void (^AutumnOpsIpPanelBusy)(BOOL busy);
typedef void (^AutumnOpsIpPageLoader)(NSInteger page, NSInteger limit, AutumnOpsIpActiveFilter filter,
                                     void (^done)(AutumnOpsIpPage * _Nullable page, NSError * _Nullable error));
typedef void (^AutumnOpsIpAddBlock)(NSString * _Nullable ip, BOOL claimCurrent,
                                    void (^done)(AutumnOpsIpUpsertResult * _Nullable result, NSError * _Nullable error));
typedef void (^AutumnOpsIpRemoveBlock)(NSString *ip, NSString * _Nullable clearToken, void (^done)(NSError * _Nullable error));
typedef void (^AutumnOpsIpToggleBlock)(NSString *ip, BOOL enable, void (^done)(NSError * _Nullable error));
typedef void (^AutumnOpsIpClearTokenResolver)(NSString *reason, void (^done)(NSString * _Nullable token)); // nil = cancelled

@interface AutumnOpsIpListPanelView : UIView

@property (nonatomic, copy) NSString *currentIp;
@property (nonatomic) BOOL claimCurrentHidden;

- (instancetype)initWithTitle:(NSString *)title
                  description:(NSString *)description
                   statusMode:(AutumnOpsIpStatusMode)statusMode
                  ipInputHint:(NSString *)ipInputHint
            allowClaimCurrent:(BOOL)allowClaimCurrent
  requireClearTokenForCurrent:(BOOL)requireClearToken
          rejectPolicyBlackIp:(BOOL)rejectPolicyBlackIp
                       header:(nullable UIView *)header
                     loadPage:(AutumnOpsIpPageLoader)loadPage
                        onAdd:(AutumnOpsIpAddBlock)onAdd
                     onRemove:(AutumnOpsIpRemoveBlock)onRemove
                     onToggle:(AutumnOpsIpToggleBlock)onToggle
            resolveClearToken:(nullable AutumnOpsIpClearTokenResolver)resolveClearToken
        onMembershipMayChange:(nullable void (^)(void))onMembershipMayChange
                        toast:(AutumnOpsIpPanelToast)toast
                      setBusy:(AutumnOpsIpPanelBusy)setBusy;

- (void)reload;

@end

NS_ASSUME_NONNULL_END
