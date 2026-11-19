#import <Foundation/Foundation.h>
@class AutumnOpsStore;
@class AutumnOpsProbeOutcome;
NS_ASSUME_NONNULL_BEGIN

@interface AutumnOpsEndpointPlan : NSObject
@property (nonatomic, copy) NSArray<NSString *> *candidates;
@property (nonatomic, copy) NSString *kind; // domain|ip|explicit
@property (nonatomic, readonly) BOOL isEmpty;
@end

@interface AutumnOpsResolvedProbe : NSObject
@property (nonatomic, copy) NSString *baseUrl;
@property (nonatomic, strong) AutumnOpsProbeOutcome *outcome;
@property (nonatomic, copy) NSArray<NSString *> *tried;
@end

@interface AutumnOpsEndpoint : NSObject
+ (NSString *)normalizeBaseUrl:(NSString *)u;
+ (AutumnOpsEndpointPlan *)resolve:(NSString *)raw;
/// 按候选探测；仅 network 失败时试下一个（对齐 Flutter OpsEndpoint.probePlan）
+ (void)probePlan:(AutumnOpsEndpointPlan *)plan
            store:(AutumnOpsStore *)store
     hasLocalCert:(BOOL)hasLocalCert
       completion:(void (^)(AutumnOpsResolvedProbe *resolved))completion;
@end

NS_ASSUME_NONNULL_END
