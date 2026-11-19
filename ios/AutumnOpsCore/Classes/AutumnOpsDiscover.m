#import "AutumnOpsDiscover.h"
#import "AutumnOpsSiteStore.h"

@implementation AutumnOpsDiscover

+ (NSString *)discoverPath { return @"/ops/discover"; }

+ (NSString *)shareUrlForBase:(NSString *)baseUrl {
  NSString *b = [AutumnOpsSiteEntry normalizeBaseUrl:baseUrl];
  if (!b.length) return @"";
  return [b stringByAppendingString:[self discoverPath]];
}

+ (nullable NSString *)tryParseBaseUrl:(NSString *)raw {
  return [self tryParseBaseUrl:raw forceHttpBase:NO];
}

+ (nullable NSString *)_parseVcAutumnOps:(NSString *)s {
  NSURLComponents *c = [NSURLComponents componentsWithString:s];
  if (!c) return nil;
  NSString *scheme = c.scheme.lowercaseString;
  BOOL app = [scheme isEqualToString:@"crchat"] || [scheme isEqualToString:@"xsign"] || [scheme isEqualToString:@"chaoranxin"];
  NSMutableArray *segs = [NSMutableArray array];
  for (NSString *p in [c.path componentsSeparatedByString:@"/"]) {
    if (p.length) [segs addObject:p];
  }
  BOOL hostVc = [c.host.lowercaseString isEqualToString:@"vc"];
  BOOL isOps = (hostVc && segs.count && [segs.firstObject isEqualToString:@"autumnops"]) || [segs containsObject:@"autumnops"];
  NSString *queryBase = nil;
  for (NSURLQueryItem *item in c.queryItems) {
    if ([item.name isEqualToString:@"base"] || [item.name isEqualToString:@"url"] || [item.name isEqualToString:@"u"]) {
      queryBase = item.value;
      break;
    }
  }
  if (app && isOps && queryBase.length) return [queryBase stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  return nil;
}

+ (nullable NSString *)_originOf:(NSURL *)uri {
  if (!uri.host.length) return nil;
  NSString *port = uri.port ? [NSString stringWithFormat:@":%@", uri.port] : @"";
  return [NSString stringWithFormat:@"%@://%@%@", uri.scheme, uri.host, port];
}

+ (nullable NSString *)tryParseBaseUrl:(NSString *)raw forceHttpBase:(BOOL)forceHttpBase {
  NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!s.length) return nil;
  NSString *vc = [self _parseVcAutumnOps:s];
  if (vc) return [AutumnOpsSiteEntry normalizeBaseUrl:vc];
  NSURL *uri = [NSURL URLWithString:s];
  if (!uri || (!([uri.scheme isEqualToString:@"http"] || [uri.scheme isEqualToString:@"https"]))) return nil;
  NSString *pathNorm = uri.path ?: @"";
  if ([pathNorm hasSuffix:@"/"] && pathNorm.length > 1) pathNorm = [pathNorm substringToIndex:pathNorm.length - 1];
  NSString *discover = [self discoverPath];
  if ([pathNorm isEqualToString:discover] || [pathNorm hasSuffix:discover]) {
    NSString *origin = [self _originOf:uri];
    if (!origin) return nil;
    if ([pathNorm isEqualToString:discover]) return [AutumnOpsSiteEntry normalizeBaseUrl:origin];
    NSRange idx = [pathNorm rangeOfString:discover options:NSBackwardsSearch];
    NSString *prefix = [pathNorm substringToIndex:idx.location];
    return [AutumnOpsSiteEntry normalizeBaseUrl:[origin stringByAppendingString:prefix]];
  }
  NSURLComponents *comp = [NSURLComponents componentsWithURL:uri resolvingAgainstBaseURL:NO];
  NSString *q = nil;
  for (NSURLQueryItem *item in comp.queryItems) {
    if ([item.name isEqualToString:@"autumn_ops"]) { q = item.value; break; }
  }
  NSString *frag = uri.fragment ?: @"";
  BOOL flagged = [q isEqualToString:@"1"] || [q isEqualToString:@"true"] || [frag isEqualToString:@"autumn_ops"] || [frag hasPrefix:@"autumn_ops="];
  if (flagged || forceHttpBase) {
    NSString *origin = [self _originOf:uri] ?: @"";
    NSString *path = uri.path ?: @"";
    if ([path hasSuffix:@"/"] && path.length > 1) path = [path substringToIndex:path.length - 1];
    return [AutumnOpsSiteEntry normalizeBaseUrl:[origin stringByAppendingString:path]];
  }
  return nil;
}

@end
