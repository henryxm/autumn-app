#import "AutumnOpsEndpoint.h"
#import "AutumnOpsClient.h"
#import "AutumnOpsProbeOutcome.h"
#import "AutumnOpsStore.h"

@implementation AutumnOpsEndpointPlan
- (BOOL)isEmpty { return self.candidates.count == 0; }
@end

@implementation AutumnOpsResolvedProbe
@end

@implementation AutumnOpsEndpoint
+ (NSString *)normalizeBaseUrl:(NSString *)u {
  NSString *s = [u stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  while ([s hasSuffix:@"/"]) s = [s substringToIndex:s.length-1];
  return s;
}
+ (BOOL)_isIPv4:(NSString *)h {
  NSArray *p = [h componentsSeparatedByString:@"."];
  if (p.count != 4) return NO;
  for (NSString *x in p) {
    NSInteger n = x.integerValue;
    if (n < 0 || n > 255 || x.length == 0) return NO;
  }
  return YES;
}
+ (AutumnOpsEndpointPlan *)resolve:(NSString *)raw {
  AutumnOpsEndpointPlan *plan = [AutumnOpsEndpointPlan new];
  NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!s.length) { plan.candidates = @[]; plan.kind = @"empty"; return plan; }
  if ([s hasPrefix:@"http://"] || [s hasPrefix:@"https://"]) {
    plan.kind = @"explicit";
    plan.candidates = @[[self normalizeBaseUrl:s]];
    return plan;
  }
  NSString *host = s;
  if ([self _isIPv4:[host componentsSeparatedByString:@":"].firstObject]) {
    plan.kind = @"ip";
    plan.candidates = @[[self normalizeBaseUrl:[@"http://" stringByAppendingString:host]]];
  } else {
    plan.kind = @"domain";
    plan.candidates = @[
      [self normalizeBaseUrl:[@"https://" stringByAppendingString:host]],
      [self normalizeBaseUrl:[@"http://" stringByAppendingString:host]],
    ];
  }
  return plan;
}

+ (void)probePlan:(AutumnOpsEndpointPlan *)plan
            store:(AutumnOpsStore *)store
     hasLocalCert:(BOOL)hasLocalCert
       completion:(void (^)(AutumnOpsResolvedProbe *))completion {
  if (plan.isEmpty) {
    AutumnOpsResolvedProbe *r = [AutumnOpsResolvedProbe new];
    r.baseUrl = @"";
    r.tried = @[];
    AutumnOpsProbeOutcome *o = [AutumnOpsProbeOutcome new];
    o.kind = AutumnOpsProbeKindNetwork;
    o.message = @"站点地址为空";
    r.outcome = o;
    if (completion) completion(r);
    return;
  }
  NSArray *cands = plan.candidates;
  NSMutableArray *tried = [NSMutableArray array];
  __block NSUInteger idx = 0;
  __block void (^step)(void);
  step = ^{
    if (idx >= cands.count) return;
    NSString *base = cands[idx++];
    [tried addObject:base];
    AutumnOpsClient *client = [[AutumnOpsClient alloc] initWithBaseUrl:base store:store];
    [client probeOutcomeHasLocalCert:hasLocalCert completion:^(AutumnOpsProbeOutcome *outcome) {
      if (outcome.kind != AutumnOpsProbeKindNetwork || idx >= cands.count) {
        AutumnOpsResolvedProbe *r = [AutumnOpsResolvedProbe new];
        r.baseUrl = base;
        r.outcome = outcome;
        r.tried = [tried copy];
        if (completion) completion(r);
        return;
      }
      step();
    }];
  };
  step();
}
@end
