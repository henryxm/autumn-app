#import <Foundation/Foundation.h>
#import "AutumnOpsModels.h"
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, AutumnOpsProbeKind) {
  AutumnOpsProbeKindNetwork = 0,
  AutumnOpsProbeKindIncompatible,
  AutumnOpsProbeKindForbidden,
  AutumnOpsProbeKindPending,
  AutumnOpsProbeKindReady,
  AutumnOpsProbeKindNeedReset,
};
@interface AutumnOpsProbeOutcome : NSObject
@property (nonatomic) AutumnOpsProbeKind kind;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy, nullable) NSString *nextStep;
@property (nonatomic, strong, nullable) AutumnOpsProbeResult *result;
+ (instancetype)fromSuccess:(AutumnOpsProbeResult *)r hasLocalCert:(BOOL)hasLocalCert;
+ (instancetype)fromErrorMessage:(NSString *)msg;
@end
NS_ASSUME_NONNULL_END
