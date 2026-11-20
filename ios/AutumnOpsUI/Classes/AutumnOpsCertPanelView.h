#import <UIKit/UIKit.h>
@class AutumnOpsClient;
@class AutumnOpsSiteEntry;
@class AutumnOpsSiteStore;
@class AutumnOpsClaimIssueResult;

NS_ASSUME_NONNULL_BEGIN

typedef void (^AutumnOpsPanelToast)(NSString *message);
typedef void (^AutumnOpsPanelBusy)(BOOL busy);

/// 证书 Tab：已登记设备 / 签发认领码 / 分享密钥（对齐 Flutter `_buildCerts`）。
@interface AutumnOpsCertPanelView : UIView

- (instancetype)initWithClient:(AutumnOpsClient *)client
                     siteEntry:(AutumnOpsSiteEntry *)siteEntry
                     siteStore:(AutumnOpsSiteStore *)siteStore
                         toast:(AutumnOpsPanelToast)toast
                       setBusy:(AutumnOpsPanelBusy)setBusy
                 onNeedRefresh:(void (^)(void))onNeedRefresh
              onLastCertRevoked:(void (^)(void))onLastCertRevoked;

/// 父页同步推送的列表（避免与概览重复请求时可调用）。
- (void)applyCerts:(NSArray<NSDictionary *> *)certs activeCount:(NSInteger)activeCount;

- (void)reload;

@end

NS_ASSUME_NONNULL_END
