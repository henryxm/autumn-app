#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter OpsFusedDualFieldAction。
@interface AutumnOpsFusedDualFieldActionView : UIView
@property (nonatomic, strong, readonly) UITextField *primaryField;
@property (nonatomic, strong, readonly) UITextField *secondaryField;
@property (nonatomic, strong, readonly) UIButton *actionButton;

- (instancetype)initWithPrimaryHint:(NSString *)primaryHint
                      secondaryHint:(NSString *)secondaryHint
                        actionTitle:(NSString *)actionTitle
                             target:(nullable id)target
                             action:(nullable SEL)action;

- (void)setBarEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
