#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter `OpsFusedActionBar`：整行标签 + 右侧动作。
@interface AutumnOpsFusedActionBarView : UIView

@property (nonatomic, strong, readonly) UILabel *label;
@property (nonatomic, strong, readonly) UIButton *actionButton;

- (instancetype)initWithIconSystemName:(nullable NSString *)systemName
                           actionTitle:(NSString *)actionTitle
                                target:(nullable id)target
                                action:(nullable SEL)action;

- (void)setLabelText:(NSString *)text selected:(BOOL)selected;
- (void)setActionTitle:(NSString *)title;
- (void)setBarEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
