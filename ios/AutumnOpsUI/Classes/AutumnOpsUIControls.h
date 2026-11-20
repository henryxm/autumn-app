#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AutumnOpsChipKind) {
  AutumnOpsChipKindOn = 0,
  AutumnOpsChipKindOff,
  AutumnOpsChipKindPending,
  AutumnOpsChipKindSaved,
  AutumnOpsChipKindReady,
  AutumnOpsChipKindUnset,
  AutumnOpsChipKindError,
  AutumnOpsChipKindEmpty, // 未填写：surfaceContainerHighest
};

typedef NS_ENUM(NSInteger, AutumnOpsButtonStyle) {
  AutumnOpsButtonStyleFilled = 0,
  AutumnOpsButtonStyleOutlined,
  AutumnOpsButtonStyleTonal,
};

/// Material Chip 对齐的小胶囊（真实 padding，宽度随文案自适应）。
@interface AutumnOpsChipView : UIView
@property (nonatomic, strong, readonly) UILabel *label;
- (void)invalidateChipSize;
@end

@interface AutumnOpsUIControls : NSObject

+ (UIButton *)buttonWithTitle:(NSString *)title
                        style:(AutumnOpsButtonStyle)style
                       target:(nullable id)target
                       action:(nullable SEL)action;

+ (void)applyStyle:(AutumnOpsButtonStyle)style toButton:(UIButton *)button;

+ (AutumnOpsChipView *)chipWithText:(NSString *)text kind:(AutumnOpsChipKind)kind;
+ (AutumnOpsChipView *)chipWithText:(NSString *)text kind:(AutumnOpsChipKind)kind compact:(BOOL)compact;
+ (void)applyChipKind:(AutumnOpsChipKind)kind toChip:(AutumnOpsChipView *)chip text:(NSString *)text;

/// 令牌输入条：高 52、圆角 12；返回 bar，field/clear/action 由出参带回。
+ (UIView *)tokenInputBarWithField:(UITextField * _Nonnull * _Nonnull)outField
                       clearButton:(UIButton * _Nullable * _Nullable)outClear
                      actionButton:(UIButton * _Nonnull * _Nonnull)outAction
                            target:(nullable id)target
                            action:(nullable SEL)action;

+ (void)setControl:(UIView *)view enabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
