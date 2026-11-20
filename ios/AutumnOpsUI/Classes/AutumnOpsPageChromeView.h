#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Flutter AppBar 对齐的自绘顶栏（宿主隐藏系统 UINavigationBar 时使用）。
@interface AutumnOpsPageChromeView : UIView

@property (nonatomic, copy) NSString *titleText;
@property (nonatomic) BOOL showsBack;
@property (nonatomic, copy, nullable) void (^onBack)(void);
@property (nonatomic, strong, readonly) UIStackView *rightStack;

/// 追加右侧操作（文字/图标按钮）；图标钮固定 44×44，避免被拉伸扭曲。
- (void)addRightItem:(UIView *)item;

/// 宿主系统导航栏被隐藏（或无 nav）时返回 YES。
+ (BOOL)shouldEmbedInViewController:(UIViewController *)vc;

/// 可 pop 或可 dismiss 时返回 YES（用于 showsBack）。
+ (BOOL)canGoBackFromViewController:(UIViewController *)vc;

/// 返回：优先 pop；若已是栈根则 dismiss 所在 presented nav / vc。
+ (void)performBackFromViewController:(UIViewController *)vc;

/// 若需 embed：挂到 vc.view 顶并铺满状态栏（同色），返回 chrome；否则返回 nil 并用系统栏。
+ (nullable AutumnOpsPageChromeView *)installOnViewController:(UIViewController *)vc
                                                        title:(NSString *)title
                                                   rightItems:(nullable NSArray<UIView *> *)rightItems;

@end

NS_ASSUME_NONNULL_END
