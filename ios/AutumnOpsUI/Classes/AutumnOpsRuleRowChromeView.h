#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter OpsRuleRowChrome：
/// 第一行标题左 + meta/胶囊右；右侧同列上启停下删除；说明/日期在下。
@interface AutumnOpsRuleRowChromeView : UIView

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(nullable NSString *)subtitle
                       active:(BOOL)active
                  statusLabel:(NSString *)statusLabel
               titleMonospace:(BOOL)titleMonospace;

- (void)setHighlightedBorder:(BOOL)highlighted;

/// 第二行说明、第三行日期。
- (void)setDetail:(nullable NSString *)detail dateLine:(nullable NSString *)dateLine;

/// 状态胶囊左侧 chips（如「本机」），不另起一行。
- (void)setMetaViews:(nullable NSArray<UIView *> *)views;

/// 右侧操作列顶部（启停）。
- (void)setPrimaryActionView:(nullable UIView *)view;

/// 右侧操作列底部（删除），与 primary 同列上下对齐。
- (void)setTrailingActionView:(nullable UIView *)view;

- (void)setActionViews:(NSArray<UIView *> *)actions;

+ (UIButton *)textAction:(NSString *)title target:(nullable id)target action:(nullable SEL)action;
+ (UIButton *)destructiveTextAction:(NSString *)title target:(nullable id)target action:(nullable SEL)action;

/// 小图标按钮：默认边长 28、图标 18。
+ (UIButton *)iconActionSystemName:(NSString *)systemName
                             color:(UIColor *)color
                            target:(nullable id)target
                            action:(nullable SEL)action
               accessibilityLabel:(nullable NSString *)accessibilityLabel;

@end

NS_ASSUME_NONNULL_END
