#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter `OpsAddSection`：surfaceContainerHighest@0.4、圆角 14。
@interface AutumnOpsAddSectionView : UIView

@property (nonatomic, strong, readonly) UIStackView *contentStack;

- (instancetype)initWithTitle:(NSString *)title subtitle:(nullable NSString *)subtitle;

@end

NS_ASSUME_NONNULL_END
