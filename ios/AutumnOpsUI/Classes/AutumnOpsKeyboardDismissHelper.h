#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 滚动区点空白收起键盘（跳过 UITextField/UITextView）；并设 Interactive dismiss。
@interface AutumnOpsKeyboardDismissHelper : NSObject
+ (void)installOnScrollView:(UIScrollView *)scroll hostView:(UIView *)hostView;
@end

NS_ASSUME_NONNULL_END
