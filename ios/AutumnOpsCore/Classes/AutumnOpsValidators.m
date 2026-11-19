#import "AutumnOpsValidators.h"
#import "AutumnOpsEndpoint.h"

@implementation AutumnOpsValidateResult
+ (instancetype)ok { return [AutumnOpsValidateResult new]; }
+ (instancetype)fail:(NSString *)error {
  AutumnOpsValidateResult *r = [AutumnOpsValidateResult new];
  r.error = error;
  return r;
}
- (BOOL)ok { return self.error == nil; }
@end

@implementation AutumnOpsValidators

+ (AutumnOpsValidateResult *)_len:(NSString *)s min:(NSInteger)min max:(NSInteger)max empty:(NSString *)empty shortMsg:(NSString *)shortMsg longMsg:(NSString *)longMsg space:(NSString *)space {
  NSString *t = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!t.length) return [AutumnOpsValidateResult fail:empty];
  if ((NSInteger)t.length < min) return [AutumnOpsValidateResult fail:shortMsg];
  if ((NSInteger)t.length > max) return [AutumnOpsValidateResult fail:longMsg];
  if ([t rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound) {
    return [AutumnOpsValidateResult fail:space];
  }
  return [AutumnOpsValidateResult ok];
}

+ (AutumnOpsValidateResult *)siteTitle:(NSString *)raw {
  NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (s.length > 64) return [AutumnOpsValidateResult fail:@"显示名称不能超过 64 个字符"];
  return [AutumnOpsValidateResult ok];
}

+ (AutumnOpsValidateResult *)siteEndpoint:(NSString *)raw {
  NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!s.length) return [AutumnOpsValidateResult fail:@"请填写域名或 IP"];
  if (s.length > 256) return [AutumnOpsValidateResult fail:@"地址过长"];
  if ([s rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound) {
    return [AutumnOpsValidateResult fail:@"地址不能包含空格"];
  }
  AutumnOpsEndpointPlan *plan = [AutumnOpsEndpoint resolve:s];
  if (!plan.candidates.count) return [AutumnOpsValidateResult fail:@"地址格式无效，请填写域名、IP 或 http(s) 完整地址"];
  return [AutumnOpsValidateResult ok];
}

+ (AutumnOpsValidateResult *)enrollSecret:(NSString *)raw {
  return [self _len:raw min:8 max:512 empty:@"请填写入驻口令" shortMsg:@"入驻口令过短，请完整复制日志中的口令" longMsg:@"入驻口令过长" space:@"入驻口令不能包含空格，请勿复制多余空白"];
}

+ (AutumnOpsValidateResult *)claimSecret:(NSString *)raw {
  return [self _len:raw min:8 max:512 empty:@"请填写认领码" shortMsg:@"认领码过短，请完整粘贴" longMsg:@"认领码过长" space:@"认领码不能包含空格"];
}

+ (AutumnOpsValidateResult *)clearToken:(NSString *)raw {
  return [self _len:raw min:4 max:256 empty:@"请填写清除确认令牌" shortMsg:@"清除确认令牌过短" longMsg:@"清除确认令牌过长" space:@"清除确认令牌不能包含空格"];
}

+ (AutumnOpsValidateResult *)sharePassphrase:(NSString *)raw {
  return [self _len:raw min:6 max:128 empty:@"请填写分享口令" shortMsg:@"分享口令至少 6 位" longMsg:@"分享口令过长" space:@"分享口令不能包含空格"];
}

+ (AutumnOpsValidateResult *)wrappedBlob:(NSString *)raw {
  NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (s.length < 32) return [AutumnOpsValidateResult fail:@"运维密文过短"];
  if (s.length > 1024 * 512) return [AutumnOpsValidateResult fail:@"运维密文过长"];
  return [AutumnOpsValidateResult ok];
}

+ (AutumnOpsValidateResult *)ipOrCidr:(NSString *)raw {
  NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!s.length) return [AutumnOpsValidateResult fail:@"请填写 IP"];
  if ([s isEqualToString:@"0.0.0.0"]) return [AutumnOpsValidateResult fail:@"不能使用 0.0.0.0"];
  NSRegularExpression *v4 = [NSRegularExpression regularExpressionWithPattern:@"^(?:(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)\\.){3}(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)$" options:0 error:nil];
  NSRegularExpression *cidr = [NSRegularExpression regularExpressionWithPattern:@"^(?:(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)\\.){3}(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)/(?:[0-9]|[12]\\d|3[0-2])$" options:0 error:nil];
  if ([v4 numberOfMatchesInString:s options:0 range:NSMakeRange(0, s.length)] ||
      [cidr numberOfMatchesInString:s options:0 range:NSMakeRange(0, s.length)]) {
    return [AutumnOpsValidateResult ok];
  }
  return [AutumnOpsValidateResult fail:@"IP 格式无效"];
}

@end
