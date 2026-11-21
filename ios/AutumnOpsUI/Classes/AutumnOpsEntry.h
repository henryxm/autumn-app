#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 统一打开入口：本机已有匹配凭证 → 直推 Manage；否则 Gate（导入/发现）。
/// 宿主（XSVideo / XSign）只调本类，禁止无条件 push Gate。
@interface AutumnOpsEntry : NSObject

+ (void)openContent:(NSDictionary *)content
    onNavigationController:(UINavigationController *)nav;

/// 发现 URL / 深链：仅 `/autumn/ops/discover` 或 `…/autumnops?base=` 才异步探测。
/// 探测失败 / 非发现形态 → `handled=NO`（宿主走原 URL 流）；
/// 探测成功有证 → Manage；成功无证 → Gate；`handled=YES`。
+ (void)openDiscoverURL:(NSString *)raw
 onNavigationController:(UINavigationController *)nav
             completion:(void (^)(BOOL handled))completion;

@end

NS_ASSUME_NONNULL_END
