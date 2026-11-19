#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutumnOpsGateViewController : UIViewController
+ (instancetype)fromContent:(NSDictionary *)content;
+ (instancetype)discoverWithRawURL:(NSString *)rawURL;
@end

NS_ASSUME_NONNULL_END
