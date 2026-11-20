#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Flutter AppBar 对齐的自绘顶栏（宿主隐藏系统 UINavigationBar 时使用）。
@interface AutumnOpsPageChromeView : UIView

@property (nonatomic, copy) NSString *titleText;
@property (nonatomic) BOOL showsBack;
@property (nonatomic, copy, nullable) void (^onBack)(void);
@property (nonatomic, strong, readonly) UIStackView *rightStack;

/// 宿主系统导航栏被隐藏（或无 nav）时返回 YES。
+ (BOOL)shouldEmbedInViewController:(UIViewController *)vc;

/// 返回：优先 pop；若已是栈根则 dismiss 所在 presented nav / vc。
+ (void)performBackFromViewController:(UIViewController *)vc;

@end

NS_ASSUME_NONNULL_END
