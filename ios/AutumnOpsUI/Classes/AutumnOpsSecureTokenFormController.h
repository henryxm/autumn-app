#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter `_OpsSecureTokenDialog`；完成时回调令牌原文（未校验服务端）。
@interface AutumnOpsSecureTokenFormController : UIViewController
@property (nonatomic, copy, nullable) void (^onResult)(NSString * _Nullable token); // nil=取消

- (instancetype)initWithTitle:(NSString *)title
                       reason:(NSString *)reason
                   fieldLabel:(NSString *)fieldLabel
                  fieldHelper:(nullable NSString *)fieldHelper
                 confirmLabel:(NSString *)confirmLabel
                  initialText:(nullable NSString *)initialText;
@end

NS_ASSUME_NONNULL_END
