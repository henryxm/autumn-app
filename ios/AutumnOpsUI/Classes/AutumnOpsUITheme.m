#import "AutumnOpsUITheme.h"

/*
 Light（与历史截图 SSOT 一致）/ Dark（Flutter ColorScheme.fromSeed 0xFF1565C0 Brightness.dark）：
 dark: primary=#A9C7FF onPrimary=#08305F primaryContainer=#274777 onPrimaryContainer=#D6E3FF
       secondary=#BDC7DC secondaryContainer=#3E4758 onSecondaryContainer=#DAE2F9
       tertiary=#DCBCE1 tertiaryContainer=#563E5C onTertiaryContainer=#F9D8FD
       error=#FFB4AB errorContainer=#93000A onErrorContainer=#FFDAD6
       surface=#111318 surfaceContainerHighest=#33353A
       onSurface=#E2E2E9 onSurfaceVariant=#C4C6CF outline=#8E9099 outlineVariant=#44474E
 */

@implementation AutumnOpsUITheme

+ (UIColor *)rgb:(NSUInteger)hex {
  return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                         green:((hex >> 8) & 0xFF) / 255.0
                          blue:(hex & 0xFF) / 255.0
                         alpha:1];
}

+ (UIColor *)dynamicLight:(NSUInteger)lightHex dark:(NSUInteger)darkHex {
  UIColor *light = [self rgb:lightHex];
  UIColor *dark = [self rgb:darkHex];
  return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
    if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) return dark;
    return light;
  }];
}

/// fg @ alpha 叠在 bg 上（两端均已 resolve 当前 trait）。
+ (UIColor *)blend:(UIColor *)fg over:(UIColor *)bg alpha:(CGFloat)a {
  return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
    UIColor *f = [fg resolvedColorWithTraitCollection:trait];
    UIColor *b = [bg resolvedColorWithTraitCollection:trait];
    CGFloat fr = 0, fg_ = 0, fb = 0, fa = 0, br = 0, bg_ = 0, bb = 0, ba = 0;
    [f getRed:&fr green:&fg_ blue:&fb alpha:&fa];
    [b getRed:&br green:&bg_ blue:&bb alpha:&ba];
    return [UIColor colorWithRed:fr * a + br * (1 - a)
                           green:fg_ * a + bg_ * (1 - a)
                            blue:fb * a + bb * (1 - a)
                           alpha:1];
  }];
}

+ (UIColor *)primary { return [self dynamicLight:0x405F90 dark:0xA9C7FF]; }
+ (UIColor *)onPrimary { return [self dynamicLight:0xFFFFFF dark:0x08305F]; }
+ (UIColor *)surface { return [self dynamicLight:0xF9F9FF dark:0x111318]; }
+ (UIColor *)surfaceContainerHighest { return [self dynamicLight:0xE2E2E9 dark:0x33353A]; }
+ (UIColor *)cardFill {
  return [self blend:[self surfaceContainerHighest] over:[self surface] alpha:0.45];
}
+ (UIColor *)onSurface { return [self dynamicLight:0x191C20 dark:0xE2E2E9]; }
+ (UIColor *)onSurfaceVariant { return [self dynamicLight:0x44474E dark:0xC4C6CF]; }
+ (UIColor *)secondary { return [self dynamicLight:0x545F71 dark:0xBDC7DC]; }
+ (UIColor *)secondaryContainer { return [self dynamicLight:0xDAE2F9 dark:0x3E4758]; }
+ (UIColor *)onSecondaryContainer { return [self dynamicLight:0x3E4758 dark:0xDAE2F9]; }
+ (UIColor *)tertiary { return [self dynamicLight:0x6B5778 dark:0xDCBCE1]; }
+ (UIColor *)chipOnFill {
  return [self blend:[self secondaryContainer] over:[self surface] alpha:0.7];
}
+ (UIColor *)chipOffFill {
  return [self blend:[self errorContainer] over:[self surface] alpha:0.45];
}
+ (UIColor *)error { return [self dynamicLight:0xBA1A1A dark:0xFFB4AB]; }
+ (UIColor *)errorContainer { return [self dynamicLight:0xFFDAD6 dark:0x93000A]; }
+ (UIColor *)onErrorContainer { return [self dynamicLight:0x93000A dark:0xFFDAD6]; }
+ (UIColor *)outline { return [self dynamicLight:0x74777F dark:0x8E9099]; }
+ (UIColor *)outlineVariant { return [self dynamicLight:0xC4C6CF dark:0x44474E]; }
+ (UIColor *)outlineVariantBorder {
  return [[self outlineVariant] colorWithAlphaComponent:0.8];
}
+ (UIColor *)tertiaryContainer { return [self dynamicLight:0xF9D8FD dark:0x563E5C]; }
+ (UIColor *)onTertiaryContainer { return [self dynamicLight:0x3B2948 dark:0xF9D8FD]; }
+ (UIColor *)primaryContainer { return [self dynamicLight:0xD6E3FF dark:0x274777]; }
+ (UIColor *)onPrimaryContainer { return [self dynamicLight:0x001B3D dark:0xD6E3FF]; }
+ (UIColor *)tabAccent { return [self primary]; }

+ (void)applyBorderToLayer:(CALayer *)layer color:(UIColor *)color width:(CGFloat)width {
  layer.borderWidth = width;
  UITraitCollection *trait = UITraitCollection.currentTraitCollection;
  layer.borderColor = [color resolvedColorWithTraitCollection:trait].CGColor;
}

@end
