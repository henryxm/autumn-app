#import <UIKit/UIKit.h>
@class AutumnOpsClient;

NS_ASSUME_NONNULL_BEGIN

typedef void (^AutumnOpsPanelToast)(NSString *message);
typedef void (^AutumnOpsPanelBusy)(BOOL busy);

/// 盾牌页：设置卡 + fused 添加 + 规则列表（对齐 Flutter OpsShieldPanel）。
@interface AutumnOpsShieldPanelView : UIView
- (instancetype)initWithClient:(AutumnOpsClient *)client
                         toast:(AutumnOpsPanelToast)toast
                     setBusy:(AutumnOpsPanelBusy)setBusy;
- (void)reload;
@end

NS_ASSUME_NONNULL_END
