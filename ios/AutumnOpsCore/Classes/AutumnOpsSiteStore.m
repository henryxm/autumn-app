#import "AutumnOpsSiteStore.h"
#import "AutumnOpsEndpoint.h"

@implementation AutumnOpsSiteEntry
- (NSDictionary *)toJSON {
  NSMutableDictionary *m = [@{@"id": self.id ?: @"", @"title": self.title ?: @"", @"baseUrl": self.baseUrl ?: @"", @"enrolled": @(self.enrolled)} mutableCopy];
  if (self.siteId.length) m[@"siteId"] = self.siteId;
  if (self.certId.length) m[@"certId"] = self.certId;
  if (self.serverFingerprint.length) m[@"serverFingerprint"] = self.serverFingerprint;
  return m;
}
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsSiteEntry *o = [AutumnOpsSiteEntry new];
  o.id = [NSString stringWithFormat:@"%@", json[@"id"] ?: @""];
  o.title = [NSString stringWithFormat:@"%@", json[@"title"] ?: @""];
  o.baseUrl = [NSString stringWithFormat:@"%@", json[@"baseUrl"] ?: @""];
  o.siteId = json[@"siteId"] == nil || json[@"siteId"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"siteId"]];
  o.certId = json[@"certId"] == nil || json[@"certId"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"certId"]];
  o.serverFingerprint = json[@"serverFingerprint"] == nil || json[@"serverFingerprint"] == [NSNull null] ? nil : [NSString stringWithFormat:@"%@", json[@"serverFingerprint"]];
  o.enrolled = [json[@"enrolled"] boolValue];
  return o;
}
+ (NSString *)normalizeBaseUrl:(NSString *)u { return [AutumnOpsEndpoint normalizeBaseUrl:u]; }
+ (NSString *)siteKeyFromBaseUrl:(NSString *)baseUrl {
  NSString *n = [[self normalizeBaseUrl:baseUrl] lowercaseString];
  NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"[^a-z0-9]+" options:0 error:nil];
  return [re stringByReplacingMatchesInString:n options:0 range:NSMakeRange(0, n.length) withTemplate:@"_"];
}
@end

@implementation AutumnOpsSiteStore {
  NSURL *_root;
}
- (instancetype)initWithRootDirectory:(NSURL *)rootDir {
  self = [super init];
  if (self) _root = rootDir;
  return self;
}
+ (NSURL *)defaultRootDirectory {
  NSURL *app = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
  return [app URLByAppendingPathComponent:@"AutumnOps" isDirectory:YES];
}
- (NSURL *)_index { return [_root URLByAppendingPathComponent:@"sites.json"]; }
- (NSArray<AutumnOpsSiteEntry *> *)listSites:(NSError **)error {
  NSData *data = [NSData dataWithContentsOfURL:[self _index] options:0 error:nil];
  if (!data.length) return @[];
  id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
  if (![obj isKindOfClass:[NSArray class]]) return @[];
  NSMutableArray *out = [NSMutableArray array];
  for (id e in obj) {
    if ([e isKindOfClass:[NSDictionary class]]) [out addObject:[AutumnOpsSiteEntry fromJSON:e]];
  }
  return out;
}
- (BOOL)saveSites:(NSArray<AutumnOpsSiteEntry *> *)sites error:(NSError **)error {
  NSMutableArray *arr = [NSMutableArray array];
  for (AutumnOpsSiteEntry *s in sites) [arr addObject:[s toJSON]];
  NSData *data = [NSJSONSerialization dataWithJSONObject:arr options:NSJSONWritingPrettyPrinted error:error];
  if (!data) return NO;
  [[NSFileManager defaultManager] createDirectoryAtURL:_root withIntermediateDirectories:YES attributes:nil error:nil];
  return [data writeToURL:[self _index] options:NSDataWritingAtomic error:error];
}
- (AutumnOpsStore *)credentialStoreForBaseUrl:(NSString *)baseUrl {
  NSString *key = [AutumnOpsSiteEntry siteKeyFromBaseUrl:baseUrl];
  NSURL *dir = [_root URLByAppendingPathComponent:key isDirectory:YES];
  NSURL *file = [dir URLByAppendingPathComponent:@"credential.json"];
  return [[AutumnOpsStore alloc] initWithFileURL:file];
}
- (AutumnOpsStore *)credentialStoreForSite:(AutumnOpsSiteEntry *)site {
  return [self credentialStoreForBaseUrl:site.baseUrl ?: @""];
}
- (BOOL)upsertSite:(AutumnOpsSiteEntry *)site error:(NSError **)error {
  NSMutableArray *list = [[self listSites:error] mutableCopy] ?: [NSMutableArray array];
  NSInteger idx = NSNotFound;
  for (NSInteger i = 0; i < (NSInteger)list.count; i++) {
    AutumnOpsSiteEntry *e = list[i];
    if ([e.id isEqualToString:site.id]) { idx = i; break; }
  }
  if (idx != NSNotFound) list[idx] = site;
  else [list addObject:site];
  return [self saveSites:list error:error];
}
- (BOOL)removeSiteId:(NSString *)siteEntryId error:(NSError **)error {
  NSMutableArray *list = [[self listSites:error] mutableCopy] ?: [NSMutableArray array];
  AutumnOpsSiteEntry *removed = nil;
  NSMutableArray *kept = [NSMutableArray array];
  for (AutumnOpsSiteEntry *e in list) {
    if ([e.id isEqualToString:siteEntryId]) removed = e;
    else [kept addObject:e];
  }
  if (![self saveSites:kept error:error]) return NO;
  if (removed) [[self credentialStoreForSite:removed] clear:nil];
  return YES;
}
- (AutumnOpsSiteEntry *)findByCertId:(NSString *)certId {
  NSString *cid = [certId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!cid.length) return nil;
  AutumnOpsSiteEntry *any = nil;
  for (AutumnOpsSiteEntry *e in [self listSites:nil]) {
    if (![e.certId isEqualToString:cid]) continue;
    if (!any) any = e;
    if (e.enrolled) return e;
  }
  return any;
}
- (AutumnOpsSiteEntry *)findByBaseUrl:(NSString *)baseUrl {
  NSString *n = [AutumnOpsSiteEntry normalizeBaseUrl:baseUrl];
  if (!n.length) return nil;
  AutumnOpsSiteEntry *any = nil;
  for (AutumnOpsSiteEntry *e in [self listSites:nil]) {
    if (![[AutumnOpsSiteEntry normalizeBaseUrl:e.baseUrl] isEqualToString:n]) continue;
    if (!any) any = e;
    if (e.enrolled) return e;
  }
  return any;
}
- (BOOL)hasLocalCredential:(AutumnOpsSiteEntry *)site {
  return [[self credentialStoreForSite:site] load:nil] != nil;
}
@end
