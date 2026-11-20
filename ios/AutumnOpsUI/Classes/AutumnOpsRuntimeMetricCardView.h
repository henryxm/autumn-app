#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter OpsRuntimePanel `_card`：surfaceContainerHighest@0.55、圆角 12。
@interface AutumnOpsRuntimeMetricCardView : UIView

@property (nonatomic, strong, readonly) UIStackView *contentStack;

- (instancetype)initWithTitle:(NSString *)title;

/// 清空内容后写入 NA 正文。
- (void)setNAReason:(nullable NSString *)reason;

- (void)clearContent;

@end

NS_ASSUME_NONNULL_END
