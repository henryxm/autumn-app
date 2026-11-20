#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutumnOpsStatusPillView : UIView
- (instancetype)initWithLabel:(NSString *)label active:(BOOL)active;
- (void)setLabel:(NSString *)label active:(BOOL)active;
@end

NS_ASSUME_NONNULL_END
