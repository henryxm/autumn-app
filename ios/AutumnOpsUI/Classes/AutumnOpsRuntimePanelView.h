#import <UIKit/UIKit.h>
@class AutumnOpsClient;

NS_ASSUME_NONNULL_BEGIN

typedef void (^AutumnOpsRuntimePanelToast)(NSString *message);
typedef void (^AutumnOpsRuntimePanelBusy)(BOOL busy);

/// 对齐 Flutter OpsRuntimePanel：8 区仪表盘 + 下拉/按钮刷新。
@interface AutumnOpsRuntimePanelView : UIView

- (instancetype)initWithClient:(AutumnOpsClient *)client
                         toast:(AutumnOpsRuntimePanelToast)toast
                       setBusy:(AutumnOpsRuntimePanelBusy)setBusy;

- (void)reload;

@end

NS_ASSUME_NONNULL_END
