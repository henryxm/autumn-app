#import <UIKit/UIKit.h>
@class AutumnOpsClient;
@class AutumnOpsSiteEntry;
@class AutumnOpsSiteStore;
NS_ASSUME_NONNULL_BEGIN
@interface AutumnOpsManageViewController : UIViewController
- (instancetype)initWithClient:(AutumnOpsClient *)client DEPRECATED_MSG_ATTRIBUTE("use initWithSiteEntry:siteStore:");
- (instancetype)initWithSiteEntry:(AutumnOpsSiteEntry *)entry siteStore:(AutumnOpsSiteStore *)siteStore;
@end
NS_ASSUME_NONNULL_END
