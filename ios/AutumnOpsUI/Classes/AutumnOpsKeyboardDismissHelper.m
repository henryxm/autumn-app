#import "AutumnOpsKeyboardDismissHelper.h"
#import <objc/runtime.h>

@interface AutumnOpsKeyboardDismissProxy : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIView *hostView;
@property (nonatomic, weak) UIScrollView *scroll;
@end

@implementation AutumnOpsKeyboardDismissProxy
- (void)_dismiss {
  [self.hostView endEditing:YES];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
  UIView *v = touch.view;
  while (v && v != self.scroll) {
    if ([v isKindOfClass:[UITextField class]] || [v isKindOfClass:[UITextView class]]) return NO;
    v = v.superview;
  }
  return YES;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
  return YES;
}
@end

static const void *kAutumnOpsKBProxyKey = &kAutumnOpsKBProxyKey;

@implementation AutumnOpsKeyboardDismissHelper

+ (void)installOnScrollView:(UIScrollView *)scroll hostView:(UIView *)hostView {
  if (!scroll || !hostView) return;
  scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  scroll.delaysContentTouches = NO;
  AutumnOpsKeyboardDismissProxy *proxy = [AutumnOpsKeyboardDismissProxy new];
  proxy.hostView = hostView;
  proxy.scroll = scroll;
  objc_setAssociatedObject(scroll, kAutumnOpsKBProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:proxy action:@selector(_dismiss)];
  tap.cancelsTouchesInView = NO;
  tap.delegate = proxy;
  [scroll addGestureRecognizer:tap];
}

@end
