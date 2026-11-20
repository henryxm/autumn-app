#import <UIKit/UIKit.h>
@class AutumnOpsSiteEntry;

NS_ASSUME_NONNULL_BEGIN

/// Flutter OpsSitesPage 行卡：圆角浅底 + 标题/副标题 + 删除。
@interface AutumnOpsSiteListCell : UITableViewCell
@property (nonatomic, copy, nullable) void (^onDelete)(void);
- (void)configureWithSite:(AutumnOpsSiteEntry *)site;
@end

NS_ASSUME_NONNULL_END
