#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutumnOpsJumpEditorResult : NSObject
@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *uri;
@property (nonatomic, copy) NSString *url;
@property (nonatomic) BOOL enable;
@end

/// 对齐 Flutter Jump `_edit` Dialog：三字段 + enable SwitchRow。
@interface AutumnOpsJumpEditorController : UIViewController
@property (nonatomic, copy, nullable) void (^onSave)(AutumnOpsJumpEditorResult *result);
@property (nonatomic, copy, nullable) void (^onCancel)(void);

- (instancetype)initWithExistingHost:(nullable NSString *)host
                                 uri:(nullable NSString *)uri
                                 url:(nullable NSString *)url
                              enable:(BOOL)enable
                             isEdit:(BOOL)isEdit;
@end

NS_ASSUME_NONNULL_END
