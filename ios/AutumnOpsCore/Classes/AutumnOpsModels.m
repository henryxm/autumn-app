#import "AutumnOpsModels.h"

static NSInteger AOCInt(id v, NSInteger fb) {
  if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue];
  if ([v isKindOfClass:[NSString class]]) return [(NSString *)v integerValue] ?: fb;
  return fb;
}
static NSNumber *AOCNum(id v) {
  if (v == nil || v == [NSNull null]) return nil;
  if ([v isKindOfClass:[NSNumber class]]) return v;
  if ([v isKindOfClass:[NSString class]]) return @([(NSString *)v integerValue]);
  return nil;
}

@implementation AutumnOpsProbeResult
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsProbeResult *o = [AutumnOpsProbeResult new];
  o.autumn = [json[@"autumn"] boolValue];
  o.opsCert = [NSString stringWithFormat:@"%@", json[@"opsCert"] ?: @"none"];
  o.adminIpEnable = [json[@"adminIpEnable"] boolValue];
  o.enrollAvailable = [json[@"enrollAvailable"] boolValue];
  o.discoverEnabled = json[@"discoverEnabled"] != nil ? [json[@"discoverEnabled"] boolValue] : YES;
  o.siteId = json[@"siteId"] == nil || json[@"siteId"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"siteId"]];
  o.serverFingerprint = json[@"serverFingerprint"] == nil || json[@"serverFingerprint"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"serverFingerprint"]];
  if (json[@"protocolVersion"] != nil && json[@"protocolVersion"] != [NSNull null]) {
    o.protocolVersion = @(AOCInt(json[@"protocolVersion"], 0));
  }
  return o;
}
@end

@implementation AutumnOpsEnrollResult
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsEnrollResult *o = [AutumnOpsEnrollResult new];
  o.certId = [NSString stringWithFormat:@"%@", json[@"certId"] ?: @""];
  o.siteId = [NSString stringWithFormat:@"%@", json[@"siteId"] ?: @""];
  o.serverPublicKey = [NSString stringWithFormat:@"%@", json[@"serverPublicKey"] ?: @""];
  o.serverFingerprint = json[@"serverFingerprint"] == nil || json[@"serverFingerprint"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"serverFingerprint"]];
  return o;
}
@end

@implementation AutumnOpsClaimIssueResult
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsClaimIssueResult *o = [AutumnOpsClaimIssueResult new];
  o.claimId = [NSString stringWithFormat:@"%@", json[@"claimId"] ?: @""];
  o.claimSecret = [NSString stringWithFormat:@"%@", json[@"claimSecret"] ?: @""];
  o.expiresAt = AOCInt(json[@"expiresAt"], 0);
  o.siteId = json[@"siteId"] == nil || json[@"siteId"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"siteId"]];
  o.serverFingerprint = json[@"serverFingerprint"] == nil || json[@"serverFingerprint"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"serverFingerprint"]];
  o.label = json[@"label"] == nil || json[@"label"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"label"]];
  return o;
}
@end

@implementation AutumnOpsRevokeResult
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRevokeResult *o = [AutumnOpsRevokeResult new];
  o.success = [json[@"success"] boolValue];
  o.lastCert = [json[@"lastCert"] boolValue];
  return o;
}
@end

@implementation AutumnOpsIpRow
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsIpRow *o = [AutumnOpsIpRow new];
  o.ip = [NSString stringWithFormat:@"%@", json[@"ip"] ?: @""];
  o.tag = json[@"tag"] == nil || json[@"tag"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"tag"]];
  o.descText = json[@"description"] == nil || json[@"description"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"description"]];
  o.forbidden = AOCNum(json[@"forbidden"]);
  o.available = AOCNum(json[@"available"]);
  o.createTimeMs = AOCNum(json[@"createTime"]);
  return o;
}
@end

@implementation AutumnOpsIpUpsertResult
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsIpUpsertResult *o = [AutumnOpsIpUpsertResult new];
  o.row = [AutumnOpsIpRow fromJSON:json ?: @{}];
  o.existed = [json[@"existed"] boolValue];
  return o;
}
@end

@implementation AutumnOpsIpPage
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsIpPage *o = [AutumnOpsIpPage new];
  NSMutableArray *rows = [NSMutableArray array];
  id raw = json[@"list"];
  if ([raw isKindOfClass:[NSArray class]]) {
    for (id e in raw) {
      if ([e isKindOfClass:[NSDictionary class]]) {
        [rows addObject:[AutumnOpsIpRow fromJSON:e]];
      }
    }
  }
  o.page = AOCInt(json[@"page"], 1);
  o.limit = AOCInt(json[@"limit"], 20);
  o.count = AOCInt(json[@"count"], (NSInteger)rows.count);
  o.hasMore = [json[@"hasMore"] boolValue] || (o.page * o.limit < o.count);
  o.list = rows;
  return o;
}
@end

@implementation AutumnOpsCredentialBundle
- (NSDictionary *)toJSON {
  NSMutableDictionary *m = [@{
    @"v": @1,
    @"siteId": self.siteId ?: @"",
    @"certId": self.certId ?: @"",
    @"baseUrl": self.baseUrl ?: @"",
    @"clientPrivateKeyPem": self.clientPrivateKeyPem ?: @"",
    @"clientPublicKeyPem": self.clientPublicKeyPem ?: @"",
    @"serverPublicKey": self.serverPublicKey ?: @"",
  } mutableCopy];
  if (self.serverFingerprint.length) m[@"serverFingerprint"] = self.serverFingerprint;
  if (self.label.length) m[@"label"] = self.label;
  return m;
}
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsCredentialBundle *o = [AutumnOpsCredentialBundle new];
  o.siteId = [NSString stringWithFormat:@"%@", json[@"siteId"] ?: @""];
  o.certId = [NSString stringWithFormat:@"%@", json[@"certId"] ?: @""];
  o.baseUrl = [NSString stringWithFormat:@"%@", json[@"baseUrl"] ?: @""];
  o.clientPrivateKeyPem = [NSString stringWithFormat:@"%@", json[@"clientPrivateKeyPem"] ?: @""];
  o.clientPublicKeyPem = [NSString stringWithFormat:@"%@", json[@"clientPublicKeyPem"] ?: @""];
  o.serverPublicKey = [NSString stringWithFormat:@"%@", json[@"serverPublicKey"] ?: @""];
  o.serverFingerprint = json[@"serverFingerprint"] == nil || json[@"serverFingerprint"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"serverFingerprint"]];
  o.label = json[@"label"] == nil || json[@"label"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"label"]];
  return o;
}
@end
