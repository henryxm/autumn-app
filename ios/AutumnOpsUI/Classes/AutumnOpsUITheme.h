#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter `ColorScheme.fromSeed(0xFF1565C0)`（light / dark 动态色）。
/// 深色表与 Flutter `Brightness.dark` 同 seed 导出一致（见 .m 注释）。
@interface AutumnOpsUITheme : NSObject

+ (UIColor *)primary;
+ (UIColor *)onPrimary;
+ (UIColor *)surface;
+ (UIColor *)surfaceContainerHighest;
/// highest@0.45 over surface（对齐 Flutter OpsSectionCard）。
+ (UIColor *)cardFill;
+ (UIColor *)onSurface;
+ (UIColor *)onSurfaceVariant;
+ (UIColor *)secondary;
+ (UIColor *)secondaryContainer;
+ (UIColor *)onSecondaryContainer;
+ (UIColor *)tertiary;
/// secondaryContainer@0.7 over surface。
+ (UIColor *)chipOnFill;
/// errorContainer@0.45 over surface。
+ (UIColor *)chipOffFill;
+ (UIColor *)error;
+ (UIColor *)errorContainer;
+ (UIColor *)onErrorContainer;
+ (UIColor *)outline;
+ (UIColor *)outlineVariant;
+ (UIColor *)outlineVariantBorder;
+ (UIColor *)tertiaryContainer;
+ (UIColor *)onTertiaryContainer;
+ (UIColor *)primaryContainer;
+ (UIColor *)onPrimaryContainer;
+ (UIColor *)tabAccent;

+ (UIColor *)rgb:(NSUInteger)hex;
/// 将 [color] 解析为当前 trait 的 CGColor 写入 layer（切换深浅后须重调）。
+ (void)applyBorderToLayer:(CALayer *)layer color:(UIColor *)color width:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
