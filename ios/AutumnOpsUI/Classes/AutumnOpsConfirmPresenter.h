#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter `_confirm`：默认确认非 Destructive；删除/吊销传 destructive=YES。
@interface AutumnOpsConfirmPresenter : NSObject
+ (void)presentFrom:(UIViewController *)host
              title:(NSString *)title
               body:(NSString *)body
        destructive:(BOOL)destructive
           onConfirm:(void (^)(void))onConfirm;
@end

NS_ASSUME_NONNULL_END
