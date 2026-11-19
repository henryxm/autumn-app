#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AutumnOpsShareToChatBlock)(UIViewController *from, NSDictionary *content, void (^done)(BOOL ok));

@interface AutumnOpsShareHooks : NSObject
@property (class, nonatomic, copy, nullable) AutumnOpsShareToChatBlock toChat;
@end

NS_ASSUME_NONNULL_END
