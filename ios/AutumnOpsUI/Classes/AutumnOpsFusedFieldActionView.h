#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter `OpsFusedFieldAction`：左输入 + 右动作，高 52、圆角 12。
@interface AutumnOpsFusedFieldActionView : UIView

@property (nonatomic, strong, readonly) UITextField *textField;
@property (nonatomic, strong, readonly) UIButton *actionButton;

- (instancetype)initWithHint:(NSString *)hint
                 actionTitle:(NSString *)actionTitle
                      target:(nullable id)target
                      action:(nullable SEL)action;

- (void)setActionTitle:(NSString *)title;
- (void)setActionEnabled:(BOOL)enabled;
- (void)setFieldEnabled:(BOOL)enabled;
- (void)setObscure:(BOOL)obscure;

/// 输入框右侧配件（如粘贴）；传 nil 清除。
- (void)setTrailing:(nullable UIView *)trailing;

@end

NS_ASSUME_NONNULL_END
