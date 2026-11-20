#import "AutumnOpsRuntimeModels.h"

static NSInteger AORInt(id v, NSInteger fallback) {
  if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue];
  if ([v isKindOfClass:[NSString class]]) {
    NSInteger n = 0;
    NSScanner *sc = [NSScanner scannerWithString:(NSString *)v];
    if ([sc scanInteger:&n]) return n;
  }
  return fallback;
}

static NSNumber *AORIntOrNull(id v) {
  if (v == nil || v == [NSNull null]) return nil;
  if ([v isKindOfClass:[NSNumber class]]) return (NSNumber *)v;
  if ([v isKindOfClass:[NSString class]]) {
    NSInteger n = 0;
    NSScanner *sc = [NSScanner scannerWithString:(NSString *)v];
    if ([sc scanInteger:&n]) return @(n);
  }
  return nil;
}

static NSNumber *AORDoubleOrNull(id v) {
  if (v == nil || v == [NSNull null]) return nil;
  if ([v isKindOfClass:[NSNumber class]]) return (NSNumber *)v;
  if ([v isKindOfClass:[NSString class]]) {
    double d = 0;
    NSScanner *sc = [NSScanner scannerWithString:(NSString *)v];
    if ([sc scanDouble:&d]) return @(d);
  }
  return nil;
}

static NSString *AORStr(id v) {
  if (v == nil || v == [NSNull null]) return @"";
  return [NSString stringWithFormat:@"%@", v];
}

static NSString *AORStrOrNil(id v) {
  if (v == nil || v == [NSNull null]) return nil;
  return [NSString stringWithFormat:@"%@", v];
}

static NSDictionary *AORSection(NSDictionary *json, NSString *key) {
  id v = json[key];
  if ([v isKindOfClass:[NSDictionary class]]) return (NSDictionary *)v;
  return @{};
}

@implementation AutumnOpsRuntimeMemory
+ (instancetype)tryParse:(id)raw {
  if (![raw isKindOfClass:[NSDictionary class]]) return nil;
  NSDictionary *m = (NSDictionary *)raw;
  AutumnOpsRuntimeMemory *o = [AutumnOpsRuntimeMemory new];
  o.initBytes = AORInt(m[@"init"], 0);
  o.used = AORInt(m[@"used"], 0);
  o.committed = AORInt(m[@"committed"], 0);
  o.max = AORInt(m[@"max"], 0);
  return o;
}
- (double)usedRatio {
  NSInteger denom = self.max > 0 ? self.max : (self.committed > 0 ? self.committed : 0);
  if (denom <= 0) return 0;
  double r = (double)self.used / (double)denom;
  if (r < 0) return 0;
  if (r > 1) return 1;
  return r;
}
@end

@implementation AutumnOpsRuntimeSystem
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimeSystem *o = [AutumnOpsRuntimeSystem new];
  o.available = json[@"available"] == nil || [json[@"available"] boolValue];
  o.error = AORStrOrNil(json[@"error"]);
  o.hostname = AORStr(json[@"hostname"]);
  o.osName = AORStr(json[@"osName"]);
  o.osArch = AORStr(json[@"osArch"]);
  o.osVersion = AORStr(json[@"osVersion"]);
  o.availableProcessors = AORInt(json[@"availableProcessors"], 0);
  o.systemLoadAverage = AORDoubleOrNull(json[@"systemLoadAverage"]);
  o.processCpuLoad = AORDoubleOrNull(json[@"processCpuLoad"]);
  o.systemCpuLoad = AORDoubleOrNull(json[@"systemCpuLoad"]);
  o.physicalTotalBytes = AORIntOrNull(json[@"physicalTotalBytes"]);
  o.physicalUsedBytes = AORIntOrNull(json[@"physicalUsedBytes"]);
  o.physicalFreeBytes = AORIntOrNull(json[@"physicalFreeBytes"]);
  return o;
}
@end

@implementation AutumnOpsRuntimeJvm
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimeJvm *o = [AutumnOpsRuntimeJvm new];
  o.available = json[@"available"] == nil || [json[@"available"] boolValue];
  o.error = AORStrOrNil(json[@"error"]);
  o.uptimeMs = AORInt(json[@"uptimeMs"], 0);
  o.javaVersion = AORStr(json[@"javaVersion"]);
  o.vmName = AORStr(json[@"vmName"]);
  o.heap = [AutumnOpsRuntimeMemory tryParse:json[@"heap"]];
  o.nonHeap = [AutumnOpsRuntimeMemory tryParse:json[@"nonHeap"]];
  o.threadLive = AORInt(json[@"threadLive"], 0);
  o.threadDaemon = AORInt(json[@"threadDaemon"], 0);
  o.threadPeak = AORInt(json[@"threadPeak"], 0);
  return o;
}
@end

@implementation AutumnOpsRuntimeDiskVolume
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimeDiskVolume *o = [AutumnOpsRuntimeDiskVolume new];
  o.name = AORStr(json[@"name"]);
  o.path = AORStr(json[@"path"]);
  o.available = [json[@"available"] boolValue];
  o.error = AORStrOrNil(json[@"error"]);
  o.totalBytes = AORInt(json[@"totalBytes"], 0);
  o.usableBytes = AORInt(json[@"usableBytes"], 0);
  o.usedBytes = AORInt(json[@"usedBytes"], 0);
  return o;
}
- (double)usedRatio {
  if (self.totalBytes <= 0) return 0;
  double r = (double)self.usedBytes / (double)self.totalBytes;
  if (r < 0) return 0;
  if (r > 1) return 1;
  return r;
}
@end

@implementation AutumnOpsRuntimeDisk
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimeDisk *o = [AutumnOpsRuntimeDisk new];
  o.available = json[@"available"] == nil || [json[@"available"] boolValue];
  o.error = AORStrOrNil(json[@"error"]);
  NSMutableArray *list = [NSMutableArray array];
  id raw = json[@"volumes"];
  if ([raw isKindOfClass:[NSArray class]]) {
    for (id e in (NSArray *)raw) {
      if ([e isKindOfClass:[NSDictionary class]]) {
        [list addObject:[AutumnOpsRuntimeDiskVolume fromJSON:e]];
      }
    }
  }
  o.volumes = list;
  return o;
}
@end

@implementation AutumnOpsRuntimeDatabase
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimeDatabase *o = [AutumnOpsRuntimeDatabase new];
  o.available = [json[@"available"] boolValue];
  o.error = AORStrOrNil(json[@"error"]);
  o.poolType = AORStr(json[@"poolType"]);
  o.productName = AORStr(json[@"productName"]);
  o.productVersion = AORStr(json[@"productVersion"]);
  o.url = AORStr(json[@"url"]);
  o.activeCount = AORIntOrNull(json[@"activeCount"]);
  o.poolingCount = AORIntOrNull(json[@"poolingCount"]);
  o.waitThreadCount = AORIntOrNull(json[@"waitThreadCount"]);
  o.maxActive = AORIntOrNull(json[@"maxActive"]);
  o.minIdle = AORIntOrNull(json[@"minIdle"]);
  o.tableCount = AORIntOrNull(json[@"tableCount"]);
  o.tableCountError = AORStrOrNil(json[@"tableCountError"]);
  return o;
}
@end

@implementation AutumnOpsRuntimeBlackHit
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimeBlackHit *o = [AutumnOpsRuntimeBlackHit new];
  o.ip = AORStr(json[@"ip"]);
  o.today = AORInt(json[@"today"], 0);
  o.count = AORInt(json[@"count"], 0);
  o.tag = AORStrOrNil(json[@"tag"]);
  o.available = AORIntOrNull(json[@"available"]);
  return o;
}
@end

@implementation AutumnOpsRuntimeFirewall
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimeFirewall *o = [AutumnOpsRuntimeFirewall new];
  o.available = json[@"available"] == nil || [json[@"available"] boolValue];
  o.error = AORStrOrNil(json[@"error"]);
  o.adminIpEnable = [json[@"adminIpEnable"] boolValue];
  o.adminIpCount = AORInt(json[@"adminIpCount"], 0);
  o.ipWhiteCount = AORInt(json[@"ipWhiteCount"], 0);
  o.ipBlackCount = AORInt(json[@"ipBlackCount"], 0);
  o.firewallCount = AORInt(json[@"firewallCount"], 0);
  o.shieldAttack = [json[@"shieldAttack"] boolValue];
  o.shieldPrint = [json[@"shieldPrint"] boolValue];
  o.shieldEnabled = [json[@"shieldEnabled"] boolValue];
  o.shieldAllowedIpCount = AORInt(json[@"shieldAllowedIpCount"], 0);
  NSMutableArray *sample = [NSMutableArray array];
  id rawSample = json[@"shieldAllowedIpSample"];
  if ([rawSample isKindOfClass:[NSArray class]]) {
    for (id e in (NSArray *)rawSample) {
      NSString *s = [AORStr(e) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if (s.length) [sample addObject:s];
    }
  }
  o.shieldAllowedIpSample = sample;
  NSMutableArray *top = [NSMutableArray array];
  id rawTop = json[@"blackTopToday"];
  if ([rawTop isKindOfClass:[NSArray class]]) {
    for (id e in (NSArray *)rawTop) {
      if ([e isKindOfClass:[NSDictionary class]]) {
        [top addObject:[AutumnOpsRuntimeBlackHit fromJSON:e]];
      }
    }
  }
  o.blackTopToday = top;
  return o;
}
@end

@implementation AutumnOpsRuntimeTraffic
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimeTraffic *o = [AutumnOpsRuntimeTraffic new];
  o.available = json[@"available"] == nil || [json[@"available"] boolValue];
  o.error = AORStrOrNil(json[@"error"]);
  o.requestTotal = AORInt(json[@"requestTotal"], 0);
  NSNumber *qps = AORDoubleOrNull(json[@"approxQps"]);
  o.approxQps = qps ? qps.doubleValue : 0;
  o.visitLogDay = AORStrOrNil(json[@"visitLogDay"]);
  o.pageViewToday = AORIntOrNull(json[@"pageViewToday"]);
  o.uniqueVisitorToday = AORIntOrNull(json[@"uniqueVisitorToday"]);
  o.visitLogRowsToday = AORIntOrNull(json[@"visitLogRowsToday"]);
  o.visitLogError = AORStrOrNil(json[@"visitLogError"]);
  return o;
}
@end

@implementation AutumnOpsRuntimeRedis
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimeRedis *o = [AutumnOpsRuntimeRedis new];
  o.enabled = [json[@"enabled"] boolValue];
  o.available = [json[@"available"] boolValue];
  o.error = AORStrOrNil(json[@"error"]);
  o.version = AORStrOrNil(json[@"version"]);
  o.connectedClients = AORStrOrNil(json[@"connected_clients"]);
  o.usedMemory = AORStrOrNil(json[@"used_memory"]);
  o.keyCount = AORIntOrNull(json[@"keyCount"]);
  o.usedMemoryBytes = AORIntOrNull(json[@"usedMemoryBytes"]);
  return o;
}
@end

@implementation AutumnOpsRuntimePathItem
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimePathItem *o = [AutumnOpsRuntimePathItem new];
  o.label = AORStr(json[@"label"]);
  o.path = AORStr(json[@"path"]);
  return o;
}
@end

@implementation AutumnOpsRuntimePaths
+ (instancetype)fromJSON:(NSDictionary *)json {
  AutumnOpsRuntimePaths *o = [AutumnOpsRuntimePaths new];
  o.available = json[@"available"] == nil || [json[@"available"] boolValue];
  o.error = AORStrOrNil(json[@"error"]);
  NSMutableArray *items = [NSMutableArray array];
  id raw = json[@"items"];
  if ([raw isKindOfClass:[NSArray class]]) {
    for (id e in (NSArray *)raw) {
      if ([e isKindOfClass:[NSDictionary class]]) {
        [items addObject:[AutumnOpsRuntimePathItem fromJSON:e]];
      }
    }
  }
  o.items = items;
  return o;
}
@end

@implementation AutumnOpsRuntimeSnapshot
+ (instancetype)fromJSON:(NSDictionary *)json {
  if (![json isKindOfClass:[NSDictionary class]]) json = @{};
  AutumnOpsRuntimeSnapshot *o = [AutumnOpsRuntimeSnapshot new];
  o.collectedAt = AORInt(json[@"collectedAt"], 0);
  o.system = [AutumnOpsRuntimeSystem fromJSON:AORSection(json, @"system")];
  o.jvm = [AutumnOpsRuntimeJvm fromJSON:AORSection(json, @"jvm")];
  o.disk = [AutumnOpsRuntimeDisk fromJSON:AORSection(json, @"disk")];
  o.database = [AutumnOpsRuntimeDatabase fromJSON:AORSection(json, @"database")];
  o.firewall = [AutumnOpsRuntimeFirewall fromJSON:AORSection(json, @"firewall")];
  o.traffic = [AutumnOpsRuntimeTraffic fromJSON:AORSection(json, @"traffic")];
  o.redis = [AutumnOpsRuntimeRedis fromJSON:AORSection(json, @"redis")];
  o.paths = [AutumnOpsRuntimePaths fromJSON:AORSection(json, @"paths")];
  NSDictionary *ex = AORSection(json, @"exceptions");
  o.exceptionsSupported = [ex[@"supported"] boolValue];
  return o;
}
@end
