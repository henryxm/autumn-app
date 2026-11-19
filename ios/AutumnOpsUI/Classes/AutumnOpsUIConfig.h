#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface AutumnOpsUIConfig : NSObject
/// enroll/claim 默认设备标签；宿主 install 时设为 ios-xsvideo / ios-xsign
@property (class, nonatomic, copy, null_resettable) NSString *deviceLabel;
@end
NS_ASSUME_NONNULL_END
