#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter OpsCountChipBar：左计数胶囊；右为「加载更多」或自定义 [trailingView]。
@interface AutumnOpsCountChipBarView : UIView
- (void)configureLoaded:(NSInteger)loaded
                  total:(NSInteger)total
                hasMore:(BOOL)hasMore
            loadingMore:(BOOL)loadingMore
             emptyLabel:(NSString *)emptyLabel;
@property (nonatomic, copy, nullable) void (^onLoadMore)(void);
/// 非空时替代「加载更多」，固有宽贴右（如 IP 启停过滤）。
@property (nonatomic, strong, nullable) UIView *trailingView;
@end

NS_ASSUME_NONNULL_END
