#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 统一打开入口：本机已有匹配凭证 → 直推 Manage；否则 Gate（导入/发现）。
/// 宿主（XSVideo / XSign）只调本类，禁止无条件 push Gate。
@interface AutumnOpsEntry : NSObject

+ (void)openContent:(NSDictionary *)content
onNavigationController:(UINavigationController *)nav;

/// 无法识别发现 URL 时返回 NO。
+ (BOOL)openDiscoverURL:(NSString *)raw
onNavigationController:(UINavigationController *)nav;

@end

NS_ASSUME_NONNULL_END
