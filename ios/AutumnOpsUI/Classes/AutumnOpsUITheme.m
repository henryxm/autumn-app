#import "AutumnOpsUITheme.h"

@implementation AutumnOpsUITheme

+ (UIColor *)rgb:(NSUInteger)hex {
  return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                         green:((hex >> 8) & 0xFF) / 255.0
                          blue:(hex & 0xFF) / 255.0
                         alpha:1];
}

+ (UIColor *)primary { return [self rgb:0x405F90]; }
+ (UIColor *)onPrimary { return UIColor.whiteColor; }
+ (UIColor *)surface { return [self rgb:0xF9F9FF]; }
+ (UIColor *)surfaceContainerHighest { return [self rgb:0xE2E2E9]; }
+ (UIColor *)cardFill { return [self rgb:0xEFEFF5]; }
+ (UIColor *)onSurface { return [self rgb:0x191C20]; }
+ (UIColor *)onSurfaceVariant { return [self rgb:0x44474E]; }
+ (UIColor *)secondary { return [self rgb:0x545F71]; }
+ (UIColor *)secondaryContainer { return [self rgb:0xDAE2F9]; }
+ (UIColor *)onSecondaryContainer { return [self rgb:0x3E4758]; }
+ (UIColor *)tertiary { return [self rgb:0x6B5778]; }
+ (UIColor *)chipOnFill { return [self rgb:0xE3E9FB]; }
+ (UIColor *)chipOffFill { return [self rgb:0xFCEBED]; }
+ (UIColor *)error { return [self rgb:0xBA1A1A]; }
+ (UIColor *)errorContainer { return [self rgb:0xFFDAD6]; }
+ (UIColor *)onErrorContainer { return [self rgb:0x93000A]; }
+ (UIColor *)outline { return [self rgb:0x74777F]; }
+ (UIColor *)outlineVariant { return [self rgb:0xC4C6CF]; }
+ (UIColor *)outlineVariantBorder {
  return [[self outlineVariant] colorWithAlphaComponent:0.8];
}
+ (UIColor *)tertiaryContainer { return [self rgb:0xF9D8FD]; }
+ (UIColor *)onTertiaryContainer { return [self rgb:0x3B2948]; }
+ (UIColor *)primaryContainer { return [self rgb:0xD6E3FF]; }
+ (UIColor *)onPrimaryContainer { return [self rgb:0x001B3D]; }
+ (UIColor *)tabAccent { return [self primary]; }

+ (void)applyBorderToLayer:(CALayer *)layer color:(UIColor *)color width:(CGFloat)width {
  layer.borderWidth = width;
  layer.borderColor = color.CGColor;
}

@end
