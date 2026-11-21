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

+ (BOOL)_isAutumnOpsConfirmed:(AutumnOpsProbeKind)kind {
  switch (kind) {
    case AutumnOpsProbeKindPending:
    case AutumnOpsProbeKindReady:
    case AutumnOpsProbeKindNeedReset:
      return YES;
    case AutumnOpsProbeKindNetwork:
    case AutumnOpsProbeKindIncompatible:
    case AutumnOpsProbeKindForbidden:
    default:
      return NO;
  }
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

+ (void)openDiscoverURL:(NSString *)raw
 onNavigationController:(UINavigationController *)nav
             completion:(void (^)(BOOL handled))completion {
  void (^done)(BOOL) = ^(BOOL handled) {
    if (completion) completion(handled);
  };
  NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!trimmed.length || !nav) {
    done(NO);
    return;
  }
  NSString *base = [AutumnOpsDiscover tryParseBaseUrl:trimmed];
  if (!base.length) {
    done(NO);
    return;
  }

  AutumnOpsSiteStore *store = [self _store];
  AutumnOpsSiteEntry *existing = [store findByBaseUrl:base];
  AutumnOpsSiteEntry *tmp = existing;
  if (!tmp) {
    tmp = [AutumnOpsSiteEntry new];
    tmp.id = @"tmp";
    tmp.title = @"";
    tmp.baseUrl = base;
  }
  AutumnOpsStore *probeStore = [store credentialStoreForSite:tmp];
  BOOL hasCert = [probeStore load:nil] != nil;
  AutumnOpsEndpointPlan *plan = [AutumnOpsEndpoint resolve:base];
  [AutumnOpsEndpoint probePlan:plan store:probeStore hasLocalCert:hasCert completion:^(AutumnOpsResolvedProbe *resolved) {
    if (![self _isAutumnOpsConfirmed:resolved.outcome.kind]) {
      done(NO);
      return;
    }
    NSString *effective = resolved.baseUrl.length ? resolved.baseUrl : base;
    if (hasCert) {
      AutumnOpsSiteEntry *site = existing ?: [store findByBaseUrl:effective];
      if (!site) {
        site = [AutumnOpsSiteEntry new];
        site.id = [NSUUID UUID].UUIDString;
        site.title = effective;
        site.baseUrl = effective;
        AutumnOpsCredentialBundle *b = [probeStore load:nil];
        site.certId = b.certId;
        site.siteId = b.siteId.length ? b.siteId : resolved.outcome.result.siteId;
        site.serverFingerprint = b.serverFingerprint ?: resolved.outcome.result.serverFingerprint;
        site.enrolled = YES;
        [store upsertSite:site error:nil];
      }
      AutumnOpsManageViewController *vc = [[AutumnOpsManageViewController alloc] initWithSiteEntry:site siteStore:store];
      [nav pushViewController:vc animated:YES];
      done(YES);
      return;
    }
    AutumnOpsGateViewController *gate = [AutumnOpsGateViewController discoverWithRawURL:trimmed];
    [nav pushViewController:gate animated:YES];
    done(YES);
  }];
}

@end
