#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter OpsMetaChip：圆角 6 的小标签（如「本机」）。
@interface AutumnOpsMetaChipView : UIView
- (instancetype)initWithText:(NSString *)text;
- (void)setText:(NSString *)text;
@end

NS_ASSUME_NONNULL_END
