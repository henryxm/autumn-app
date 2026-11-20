#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Flutter Material TabBar 对齐：可横滑文字 Tab + 底部指示条（非 UISegmentedControl）。
@interface AutumnOpsScrollableTabBar : UIControl

@property (nonatomic, copy) NSArray<NSString *> *items;
@property (nonatomic) NSInteger selectedIndex;

- (instancetype)initWithItems:(NSArray<NSString *> *)items;

@end

NS_ASSUME_NONNULL_END
