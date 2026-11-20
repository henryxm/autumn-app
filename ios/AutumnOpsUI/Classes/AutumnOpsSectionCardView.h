#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Flutter `_sectionCard` 对齐：圆角 14、cardFill、标题+说明+内容。
@interface AutumnOpsSectionCardView : UIView

@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *bodyLabel;
@property (nonatomic, strong, readonly) UIStackView *contentStack;

- (instancetype)initWithTitle:(NSString *)title body:(NSString *)body;
- (void)setBodyText:(NSString *)body;
- (void)setOutlined:(BOOL)outlined;

/// 标题行左侧图标（如盾牌）；传 nil 清除。
- (void)setTitleLeading:(nullable UIView *)leading;
/// 标题行右侧配件（如 status chip）；传 nil 清除。
- (void)setTitleAccessory:(nullable UIView *)accessory;

+ (UIView *)kvRowWithKey:(NSString *)key value:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
