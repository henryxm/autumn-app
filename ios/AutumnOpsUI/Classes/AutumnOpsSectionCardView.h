#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Flutter `_sectionCard` 对齐：圆角 14、浅底、标题+说明+内容。
@interface AutumnOpsSectionCardView : UIView

@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *bodyLabel;
@property (nonatomic, strong, readonly) UIStackView *contentStack;

- (instancetype)initWithTitle:(NSString *)title body:(NSString *)body;
- (void)setBodyText:(NSString *)body;
- (void)setOutlined:(BOOL)outlined;

/// 左标签宽 96 的 kv 行（对齐 Flutter `_kv`）。
+ (UIView *)kvRowWithKey:(NSString *)key value:(NSString *)value;

/// 状态 Chip（圆角胶囊）。
+ (UILabel *)statusChipWithText:(NSString *)text on:(BOOL)on;

@end

NS_ASSUME_NONNULL_END
