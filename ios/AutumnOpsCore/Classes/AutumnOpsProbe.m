#import "AutumnOpsProbe.h"

@implementation AutumnOpsProbe
+ (NSString *)headerName { return @"X-Autumn-Ops-Probe"; }
+ (NSString *)token { return @"autumn-ops-probe"; }
+ (NSString *)sessionHeaderName { return @"X-Ops-Session"; }
@end
