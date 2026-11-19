#import "AutumnOpsPayload.h"
#import "AutumnOpsValidators.h"

@implementation AutumnOpsPayload
+ (NSString *)kind { return @"autumn-ops"; }
+ (NSString *)messageType { return @"AutumnOps"; }
+ (NSString *)fileExtension { return @"autumnops"; }
+ (NSDictionary *)toMessageMapWithWrapped:(NSString *)wrapped
                                  baseUrl:(NSString *)baseUrl
                                   siteId:(NSString *)siteId
                                   certId:(NSString *)certId
                       serverFingerprint:(NSString *)serverFingerprint
                             createdAtMs:(NSNumber *)createdAtMs {
  NSMutableDictionary *m = [@{
    @"v": @1,
    @"kind": [self kind],
    @"wrapped": [wrapped stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]],
    @"createdAt": createdAtMs ?: @((long long)([[NSDate date] timeIntervalSince1970] * 1000.0)),
  } mutableCopy];
  if (baseUrl.length) m[@"baseUrl"] = baseUrl;
  if (siteId.length) m[@"siteId"] = siteId;
  if (certId.length) m[@"certId"] = certId;
  if (serverFingerprint.length) m[@"serverFingerprint"] = serverFingerprint;
  return m;
}
- (NSDictionary *)toMap {
  return [AutumnOpsPayload toMessageMapWithWrapped:self.wrapped baseUrl:self.baseUrl siteId:self.siteId certId:self.certId serverFingerprint:self.serverFingerprint createdAtMs:self.createdAtMs];
}
@end

@implementation AutumnOpsParseResult
+ (instancetype)ok:(AutumnOpsPayload *)payload {
  AutumnOpsParseResult *r = [AutumnOpsParseResult new];
  r.payload = payload;
  return r;
}
+ (instancetype)fail:(NSString *)error {
  AutumnOpsParseResult *r = [AutumnOpsParseResult new];
  r.error = error;
  return r;
}
- (BOOL)ok { return self.payload != nil && self.error == nil; }
+ (AutumnOpsParseResult *)fromMessageMap:(NSDictionary *)map {
  NSString *k = [[NSString stringWithFormat:@"%@", map[@"kind"] ?: @""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (![k isEqualToString:[AutumnOpsPayload kind]]) {
    return [self fail:k.length ? [NSString stringWithFormat:@"不是 Autumn 运维载荷（kind=%@）", k] : @"缺少 kind=autumn-ops"];
  }
  NSString *wrapped = [[NSString stringWithFormat:@"%@", map[@"wrapped"] ?: @""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  AutumnOpsValidateResult *blob = [AutumnOpsValidators wrappedBlob:wrapped];
  if (!blob.ok) return [self fail:blob.error ?: @"运维密文无效"];
  AutumnOpsPayload *p = [AutumnOpsPayload new];
  p.wrapped = wrapped;
  p.baseUrl = map[@"baseUrl"] == nil || map[@"baseUrl"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", map[@"baseUrl"]];
  p.siteId = map[@"siteId"] == nil || map[@"siteId"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", map[@"siteId"]];
  p.certId = map[@"certId"] == nil || map[@"certId"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", map[@"certId"]];
  p.serverFingerprint = map[@"serverFingerprint"] == nil || map[@"serverFingerprint"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", map[@"serverFingerprint"]];
  if (map[@"createdAt"] != nil && map[@"createdAt"] != [NSNull null]) {
    p.createdAtMs = @([map[@"createdAt"] longLongValue]);
  }
  return [self ok:p];
}
+ (AutumnOpsParseResult *)parse:(NSString *)raw {
  NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!s.length) return [self fail:@"运维载荷为空"];
  if (![s hasPrefix:@"{"]) return [self fail:@"运维载荷须为 JSON"];
  NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];
  id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![obj isKindOfClass:[NSDictionary class]]) return [self fail:@"运维载荷 JSON 须为对象"];
  return [self fromMessageMap:obj];
}
@end
