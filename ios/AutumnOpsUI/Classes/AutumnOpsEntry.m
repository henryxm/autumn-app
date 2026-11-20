#import "AutumnOpsEntry.h"
#import "AutumnOpsGateViewController.h"
#import "AutumnOpsManageViewController.h"
#import <AutumnOpsCore/AutumnOpsCore.h>

@implementation AutumnOpsEntry

+ (AutumnOpsSiteStore *)_store {
  return [[AutumnOpsSiteStore alloc] initWithRootDirectory:[AutumnOpsSiteStore defaultRootDirectory]];
}

+ (nullable AutumnOpsSiteEntry *)_manageSiteForPayload:(AutumnOpsPayload *)payload store:(AutumnOpsSiteStore *)store {
  NSString *certId = [payload.certId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
  if (certId.length) {
    AutumnOpsSiteEntry *hit = [store findByCertId:certId];
    if (hit && [store hasLocalCredential:hit]) return hit;
  }
  NSString *baseHint = [payload.baseUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
  if (baseHint.length && certId.length) {
    AutumnOpsSiteEntry *byBase = [store findByBaseUrl:baseHint];
    if (byBase && byBase.certId.length && [byBase.certId isEqualToString:certId] && [store hasLocalCredential:byBase]) {
      return byBase;
    }
  }
  return nil;
}

+ (void)openContent:(NSDictionary *)content onNavigationController:(UINavigationController *)nav {
  if (![content isKindOfClass:[NSDictionary class]] || !nav) return;
  AutumnOpsParseResult *parsed = [AutumnOpsParseResult fromMessageMap:content];
  if (parsed.ok && parsed.payload) {
    AutumnOpsSiteStore *store = [self _store];
    AutumnOpsSiteEntry *site = [self _manageSiteForPayload:parsed.payload store:store];
    if (site) {
      AutumnOpsManageViewController *vc = [[AutumnOpsManageViewController alloc] initWithSiteEntry:site siteStore:store];
      [nav pushViewController:vc animated:YES];
      return;
    }
  }
  AutumnOpsGateViewController *gate = [AutumnOpsGateViewController fromContent:content];
  [nav pushViewController:gate animated:YES];
}

+ (BOOL)openDiscoverURL:(NSString *)raw onNavigationController:(UINavigationController *)nav {
  NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!trimmed.length || !nav) return NO;
  NSString *base = [AutumnOpsDiscover tryParseBaseUrl:trimmed] ?: [AutumnOpsDiscover tryParseBaseUrl:trimmed forceHttpBase:YES];
  if (!base.length) return NO;

  AutumnOpsSiteStore *store = [self _store];
  AutumnOpsSiteEntry *existing = [store findByBaseUrl:base];
  if (existing.enrolled && [store hasLocalCredential:existing]) {
    AutumnOpsManageViewController *vc = [[AutumnOpsManageViewController alloc] initWithSiteEntry:existing siteStore:store];
    [nav pushViewController:vc animated:YES];
    return YES;
  }
  AutumnOpsGateViewController *gate = [AutumnOpsGateViewController discoverWithRawURL:trimmed];
  [nav pushViewController:gate animated:YES];
  return YES;
}

@end
