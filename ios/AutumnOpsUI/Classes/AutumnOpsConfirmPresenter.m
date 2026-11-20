#import "AutumnOpsConfirmPresenter.h"

@implementation AutumnOpsConfirmPresenter

+ (void)presentFrom:(UIViewController *)host
              title:(NSString *)title
               body:(NSString *)body
        destructive:(BOOL)destructive
          onConfirm:(void (^)(void))onConfirm {
  UIAlertController *a = [UIAlertController alertControllerWithTitle:title
                                                             message:body
                                                      preferredStyle:UIAlertControllerStyleAlert];
  [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  UIAlertActionStyle style = destructive ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
  [a addAction:[UIAlertAction actionWithTitle:@"确认" style:style handler:^(UIAlertAction *action) {
    if (onConfirm) onConfirm();
  }]];
  [host presentViewController:a animated:YES completion:nil];
}

@end
