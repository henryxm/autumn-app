#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutumnOpsSwitchRowView : UIView
@property (nonatomic, strong, readonly) UISwitch *switchControl;
- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle;
@end

NS_ASSUME_NONNULL_END
