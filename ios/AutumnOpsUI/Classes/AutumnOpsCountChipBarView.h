#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐 Flutter OpsCountChipBar。
@interface AutumnOpsCountChipBarView : UIView
- (void)configureLoaded:(NSInteger)loaded
                  total:(NSInteger)total
                hasMore:(BOOL)hasMore
            loadingMore:(BOOL)loadingMore
           emptyLabel:(NSString *)emptyLabel;
@property (nonatomic, copy, nullable) void (^onLoadMore)(void);
@end

NS_ASSUME_NONNULL_END
