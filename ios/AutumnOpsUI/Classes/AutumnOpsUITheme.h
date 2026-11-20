#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Flutter `ColorScheme.fromSeed(0xFF1565C0)` light 对齐色（截图 SSOT）。
@interface AutumnOpsUITheme : NSObject

+ (UIColor *)primary;                 // #405F90
+ (UIColor *)onPrimary;               // #FFFFFF
+ (UIColor *)surface;                 // #F9F9FF
+ (UIColor *)surfaceContainerHighest; // #E2E2E9
+ (UIColor *)cardFill;                // #EFEFF5（highest@0.45 over surface）
+ (UIColor *)onSurface;               // #191C20
+ (UIColor *)onSurfaceVariant;        // #44474E
+ (UIColor *)secondary;               // #545F71（探测 needReset accent）
+ (UIColor *)secondaryContainer;      // #DAE2F9
+ (UIColor *)onSecondaryContainer;    // #3E4758
+ (UIColor *)tertiary;                // #6B5778（探测 pending/ready accent）
+ (UIColor *)chipOnFill;              // secondaryContainer@0.7 over surface ≈ #E3E9FB
+ (UIColor *)chipOffFill;             // errorContainer@0.45 over surface ≈ #FCEBED
+ (UIColor *)error;                   // #BA1A1A（探测失败 accent）
+ (UIColor *)errorContainer;          // #FFDAD6
+ (UIColor *)onErrorContainer;        // #93000A
+ (UIColor *)outline;                 // #74777F
+ (UIColor *)outlineVariant;          // #C4C6CF
+ (UIColor *)outlineVariantBorder;    // outlineVariant@0.8
+ (UIColor *)tertiaryContainer;       // #F9D8FD
+ (UIColor *)onTertiaryContainer;     // #3B2948 附近
+ (UIColor *)primaryContainer;        // #D6E3FF
+ (UIColor *)onPrimaryContainer;      // #001B3D 附近
+ (UIColor *)tabAccent;               // primary

+ (UIColor *)rgb:(NSUInteger)hex;
+ (void)applyBorderToLayer:(CALayer *)layer color:(UIColor *)color width:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
