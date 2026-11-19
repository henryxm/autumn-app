#import "AutumnOpsClient.h"
#import "AutumnOpsProbe.h"
#import "AutumnOpsCrypto.h"
#import "AutumnOpsEndpoint.h"

@implementation AutumnOpsClient {
  NSString *_sessionId;
  AutumnOpsCredentialBundle *_bundle;
  NSURLSession *_session;
}

- (instancetype)initWithBaseUrl:(NSString *)baseUrl store:(AutumnOpsStore *)store {
  self = [super init];
  if (self) {
    _baseUrl = [AutumnOpsEndpoint normalizeBaseUrl:baseUrl];
    _store = store;
    _deviceLabel = @"ios";
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 30;
    cfg.HTTPAdditionalHeaders = @{ @"Content-Type": @"application/json" };
    _session = [NSURLSession sessionWithConfiguration:cfg];
  }
  return self;
}

- (NSString *)root {
  return _baseUrl;
}

- (void)_postPath:(NSString *)path
             body:(NSDictionary *)body
          headers:(NSDictionary *)headers
       completion:(void (^)(NSDictionary * _Nullable data, NSError * _Nullable error))completion {
  NSString *urlStr = [NSString stringWithFormat:@"%@%@", self.root, path];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
  req.HTTPMethod = @"POST";
  for (NSString *k in headers) {
    [req setValue:headers[k] forHTTPHeaderField:k];
  }
  NSData *payload = [NSJSONSerialization dataWithJSONObject:body ?: @{} options:0 error:nil];
  req.HTTPBody = payload;
  [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (error) {
      dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
      return;
    }
    NSInteger code = [(NSHTTPURLResponse *)response statusCode];
    NSError *jerr = nil;
    id obj = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&jerr] : nil;
    if (![obj isKindOfClass:[NSDictionary class]]) {
      NSError *e = [NSError errorWithDomain:@"AutumnOpsClient" code:code userInfo:@{NSLocalizedDescriptionKey: @"invalid JSON response"}];
      dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, e); });
      return;
    }
    NSDictionary *bodyDict = (NSDictionary *)obj;
    id c = bodyDict[@"code"];
    if (c != nil && [c integerValue] != 0) {
      NSString *msg = [NSString stringWithFormat:@"%@ (%@)", bodyDict[@"msg"] ?: @"ops error", c];
      NSError *e = [NSError errorWithDomain:@"AutumnOpsClient" code:[c integerValue] userInfo:@{NSLocalizedDescriptionKey: msg}];
      dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, e); });
      return;
    }
    id dataObj = bodyDict[@"data"];
    NSDictionary *out = nil;
    if ([dataObj isKindOfClass:[NSDictionary class]]) out = dataObj;
    else out = bodyDict;
    if (code == 401) {
      NSError *e = [NSError errorWithDomain:@"AutumnOpsClient" code:401 userInfo:@{NSLocalizedDescriptionKey: @"unauthorized"}];
      dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, e); });
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{ completion(out, nil); });
  }] resume];
}

- (void)probe:(AutumnOpsProbeBlock)completion {
  [self _postPath:@"/ops/api/v1/probe" body:@{} headers:@{ [AutumnOpsProbe headerName]: [AutumnOpsProbe token] } completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(nil, error); return; }
    completion([AutumnOpsProbeResult fromJSON:data], nil);
  }];
}

- (void)probeOutcomeHasLocalCert:(BOOL)hasLocalCert completion:(AutumnOpsProbeOutcomeBlock)completion {
  [self probe:^(AutumnOpsProbeResult *result, NSError *error) {
    if (error) {
      completion([AutumnOpsProbeOutcome fromErrorMessage:error.localizedDescription]);
      return;
    }
    completion([AutumnOpsProbeOutcome fromSuccess:result hasLocalCert:hasLocalCert]);
  }];
}

- (void)_persistEnrolled:(AutumnOpsEnrollResult *)enrolled pub:(NSString *)pubPem pri:(NSString *)priPem label:(NSString *)label completion:(AutumnOpsEnrollBlock)completion {
  AutumnOpsCredentialBundle *bundle = [AutumnOpsCredentialBundle new];
  bundle.siteId = enrolled.siteId;
  bundle.certId = enrolled.certId;
  bundle.baseUrl = self.root;
  bundle.clientPrivateKeyPem = priPem;
  bundle.clientPublicKeyPem = pubPem;
  bundle.serverPublicKey = enrolled.serverPublicKey;
  bundle.serverFingerprint = enrolled.serverFingerprint;
  bundle.label = label;
  NSError *err = nil;
  if (![self.store save:bundle error:&err]) {
    completion(nil, err);
    return;
  }
  _bundle = bundle;
  _sessionId = nil;
  completion(enrolled, nil);
}

- (void)enrollWithSecret:(NSString *)secret completion:(AutumnOpsEnrollBlock)completion {
  NSError *err = nil;
  AutumnOpsKeyPair *pair = [AutumnOpsCrypto generateRsa2048:&err];
  if (!pair) { completion(nil, err); return; }
  NSDictionary *body = @{
    @"secret": secret,
    @"clientPublicKey": [AutumnOpsCrypto stripPem:pair.publicKeyPem],
    @"label": self.deviceLabel ?: @"ios",
  };
  [self _postPath:@"/ops/api/v1/enroll" body:body headers:@{} completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(nil, error); return; }
    AutumnOpsEnrollResult *enrolled = [AutumnOpsEnrollResult fromJSON:data];
    [self _persistEnrolled:enrolled pub:pair.publicKeyPem pri:pair.privateKeyPem label:self.deviceLabel ?: @"ios" completion:completion];
  }];
}

- (void)claimWithSecret:(NSString *)claimSecret completion:(AutumnOpsEnrollBlock)completion {
  NSError *err = nil;
  AutumnOpsKeyPair *pair = [AutumnOpsCrypto generateRsa2048:&err];
  if (!pair) { completion(nil, err); return; }
  NSDictionary *body = @{
    @"claimSecret": claimSecret,
    @"clientPublicKey": [AutumnOpsCrypto stripPem:pair.publicKeyPem],
    @"label": self.deviceLabel ?: @"ios",
  };
  [self _postPath:@"/ops/api/v1/cert/claim" body:body headers:@{} completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(nil, error); return; }
    AutumnOpsEnrollResult *enrolled = [AutumnOpsEnrollResult fromJSON:data];
    [self _persistEnrolled:enrolled pub:pair.publicKeyPem pri:pair.privateKeyPem label:self.deviceLabel ?: @"ios" completion:completion];
  }];
}

- (void)ensureSession:(AutumnOpsVoidBlock)completion {
  NSError *err = nil;
  AutumnOpsCredentialBundle *bundle = [self _loadBundle:&err];
  if (!bundle) { completion(err); return; }
  [self _postPath:@"/ops/api/v1/challenge" body:@{ @"certId": bundle.certId } headers:@{} completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(error); return; }
    NSString *nonce = [NSString stringWithFormat:@"%@", data[@"nonce"] ?: @""];
    NSError *sErr = nil;
    NSString *signature = [AutumnOpsCrypto signSha256RsaPem:bundle.clientPrivateKeyPem payload:nonce error:&sErr];
    if (!signature) { completion(sErr); return; }
    NSString *aesKey = [AutumnOpsCrypto randomAesKeyBase64];
    NSString *aesIv = [AutumnOpsCrypto randomIvBase64];
    NSString *wrapped = [AutumnOpsCrypto rsaEncryptToBase64Pem:bundle.serverPublicKey plain:aesKey error:&sErr];
    if (!wrapped) { completion(sErr); return; }
    NSDictionary *body = @{
      @"certId": bundle.certId,
      @"nonce": nonce,
      @"signature": signature,
      @"aesKeyWrapped": wrapped,
      @"aesIv": aesIv,
    };
    [self _postPath:@"/ops/api/v1/session" body:body headers:@{} completion:^(NSDictionary *sdata, NSError *serror) {
      if (serror) { completion(serror); return; }
      self->_sessionId = [NSString stringWithFormat:@"%@", sdata[@"sessionId"] ?: @""];
      if (!self->_sessionId.length) {
        completion([NSError errorWithDomain:@"AutumnOpsClient" code:3 userInfo:@{NSLocalizedDescriptionKey: @"ops session empty"}]);
        return;
      }
      completion(nil);
    }];
  }];
}

- (AutumnOpsCredentialBundle *)_loadBundle:(NSError **)error {
  if (!_bundle) _bundle = [self.store load:error];
  if (!_bundle) {
    if (error && !*error) {
      *error = [NSError errorWithDomain:@"AutumnOpsClient" code:4 userInfo:@{NSLocalizedDescriptionKey: @"not enrolled: enroll or import credential first"}];
    }
  }
  return _bundle;
}

- (void)_authedPost:(NSString *)path body:(NSDictionary *)body completion:(AutumnOpsDictBlock)completion {
  void (^go)(void) = ^{
    NSDictionary *headers = @{ [AutumnOpsProbe sessionHeaderName]: self->_sessionId ?: @"" };
    [self _postPath:path body:body headers:headers completion:^(NSDictionary *data, NSError *error) {
      if (error && error.code == 401) {
        self->_sessionId = nil;
        [self ensureSession:^(NSError *e2) {
          if (e2) { completion(nil, e2); return; }
          NSDictionary *h2 = @{ [AutumnOpsProbe sessionHeaderName]: self->_sessionId ?: @"" };
          [self _postPath:path body:body headers:h2 completion:completion];
        }];
        return;
      }
      completion(data, error);
    }];
  };
  if (!_sessionId.length) {
    [self ensureSession:^(NSError *error) {
      if (error) { completion(nil, error); return; }
      go();
    }];
  } else {
    go();
  }
}

#pragma mark - Admin APIs

- (void)adminIpListPage:(NSInteger)page limit:(NSInteger)limit completion:(AutumnOpsIpPageBlock)completion {
  [self _authedPost:@"/ops/api/v1/adminip/list" body:@{ @"page": @(page), @"limit": @(limit) } completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(nil, error); return; }
    completion([AutumnOpsIpPage fromJSON:data], nil);
  }];
}
- (void)adminIpAdd:(NSString *)ip claimCurrent:(BOOL)claimCurrent completion:(AutumnOpsDictBlock)completion {
  NSMutableDictionary *b = [@{ @"claimCurrent": @(claimCurrent) } mutableCopy];
  if (ip.length) b[@"ip"] = ip;
  [self _authedPost:@"/ops/api/v1/adminip/add" body:b completion:completion];
}
- (void)adminIpRemove:(NSString *)ip clearToken:(NSString *)clearToken completion:(AutumnOpsDictBlock)completion {
  NSMutableDictionary *b = [@{ @"ip": ip ?: @"" } mutableCopy];
  if (clearToken.length) b[@"clearToken"] = clearToken;
  [self _authedPost:@"/ops/api/v1/adminip/remove" body:b completion:completion];
}
- (void)adminIpSetForbidden:(NSString *)ip forbidden:(BOOL)forbidden completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/adminip/setForbidden" body:@{ @"ip": ip ?: @"", @"forbidden": @(forbidden ? 1 : 0) } completion:completion];
}
- (void)currentIp:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/currentIp" body:@{} completion:completion];
}

- (void)ipWhiteListPage:(NSInteger)page limit:(NSInteger)limit completion:(AutumnOpsIpPageBlock)completion {
  [self _authedPost:@"/ops/api/v1/ipwhite/list" body:@{ @"page": @(page), @"limit": @(limit) } completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(nil, error); return; }
    completion([AutumnOpsIpPage fromJSON:data], nil);
  }];
}
- (void)ipWhiteAdd:(NSString *)ip claimCurrent:(BOOL)claimCurrent completion:(AutumnOpsDictBlock)completion {
  NSMutableDictionary *b = [@{ @"claimCurrent": @(claimCurrent) } mutableCopy];
  if (ip.length) b[@"ip"] = ip;
  [self _authedPost:@"/ops/api/v1/ipwhite/add" body:b completion:completion];
}
- (void)ipWhiteRemove:(NSString *)ip clearToken:(NSString *)clearToken completion:(AutumnOpsDictBlock)completion {
  NSMutableDictionary *b = [@{ @"ip": ip ?: @"" } mutableCopy];
  if (clearToken.length) b[@"clearToken"] = clearToken;
  [self _authedPost:@"/ops/api/v1/ipwhite/remove" body:b completion:completion];
}
- (void)ipWhiteSetForbidden:(NSString *)ip forbidden:(BOOL)forbidden completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/ipwhite/setForbidden" body:@{ @"ip": ip ?: @"", @"forbidden": @(forbidden ? 1 : 0) } completion:completion];
}

- (void)ipBlackListPage:(NSInteger)page limit:(NSInteger)limit completion:(AutumnOpsIpPageBlock)completion {
  [self _authedPost:@"/ops/api/v1/ipblack/list" body:@{ @"page": @(page), @"limit": @(limit) } completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(nil, error); return; }
    completion([AutumnOpsIpPage fromJSON:data], nil);
  }];
}
- (void)ipBlackAdd:(NSString *)ip completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/ipblack/add" body:@{ @"ip": ip ?: @"" } completion:completion];
}
- (void)ipBlackRemove:(NSString *)ip completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/ipblack/remove" body:@{ @"ip": ip ?: @"" } completion:completion];
}
- (void)ipBlackSetAvailable:(NSString *)ip available:(NSInteger)available completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/ipblack/setAvailable" body:@{ @"ip": ip ?: @"", @"available": @(available) } completion:completion];
}
- (void)ipBlackFirewallCount:(AutumnOpsIntBlock)completion {
  [self _authedPost:@"/ops/api/v1/ipblack/firewallCount/get" body:@{} completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(0, error); return; }
    completion([data[@"firewallCount"] integerValue], nil);
  }];
}
- (void)ipBlackSetFirewallCount:(NSInteger)count completion:(AutumnOpsIntBlock)completion {
  [self _authedPost:@"/ops/api/v1/ipblack/firewallCount/set" body:@{ @"count": @(count) } completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(count, error); return; }
    completion([data[@"firewallCount"] integerValue] ?: count, nil);
  }];
}

- (void)shieldListPage:(NSInteger)page limit:(NSInteger)limit completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/shield/list" body:@{ @"page": @(page), @"limit": @(limit) } completion:completion];
}
- (void)shieldSaveUri:(NSString *)uri enable:(BOOL)enable autoValue:(NSInteger)autoValue completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/shield/save" body:@{ @"uri": uri ?: @"", @"enable": @(enable), @"auto": @(autoValue) } completion:completion];
}
- (void)shieldUpdateId:(NSInteger)sid uri:(NSString *)uri enable:(NSNumber *)enable autoValue:(NSNumber *)autoValue completion:(AutumnOpsDictBlock)completion {
  NSMutableDictionary *b = [@{ @"id": @(sid) } mutableCopy];
  if (uri.length) b[@"uri"] = uri;
  if (enable) b[@"enable"] = enable;
  if (autoValue) b[@"auto"] = autoValue;
  [self _authedPost:@"/ops/api/v1/shield/update" body:b completion:completion];
}
- (void)shieldDeleteIds:(NSArray<NSNumber *> *)ids completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/shield/delete" body:@{ @"ids": ids ?: @[] } completion:completion];
}
- (void)shieldStatus:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/shield/status" body:@{} completion:completion];
}
- (void)shieldSetAttack:(BOOL)attack completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/shield/setAttack" body:@{ @"attack": @(attack) } completion:completion];
}
- (void)shieldSetPrint:(BOOL)print completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/shield/setPrint" body:@{ @"print": @(print) } completion:completion];
}
- (void)shieldSetEnable:(BOOL)enable completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/shield/setEnable" body:@{ @"enable": @(enable) } completion:completion];
}

- (void)jumpListPage:(NSInteger)page limit:(NSInteger)limit completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/jump/list" body:@{ @"page": @(page), @"limit": @(limit) } completion:completion];
}
- (void)jumpSaveHost:(NSString *)host uri:(NSString *)uri url:(NSString *)url enable:(BOOL)enable completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/jump/save" body:@{ @"host": host ?: @"", @"uri": uri ?: @"", @"url": url ?: @"", @"enable": @(enable) } completion:completion];
}
- (void)jumpUpdateId:(NSInteger)jid host:(NSString *)host uri:(NSString *)uri url:(NSString *)url enable:(NSNumber *)enable completion:(AutumnOpsDictBlock)completion {
  NSMutableDictionary *b = [@{ @"id": @(jid) } mutableCopy];
  if (host.length) b[@"host"] = host;
  if (uri.length) b[@"uri"] = uri;
  if (url.length) b[@"url"] = url;
  if (enable) b[@"enable"] = enable;
  [self _authedPost:@"/ops/api/v1/jump/update" body:b completion:completion];
}
- (void)jumpDeleteIds:(NSArray<NSNumber *> *)ids completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/jump/delete" body:@{ @"ids": ids ?: @[] } completion:completion];
}

- (void)gateGet:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/gate/get" body:@{} completion:completion];
}
- (void)runtimeSnapshot:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/runtime/snapshot" body:@{} completion:completion];
}
- (void)gateVerifyClearToken:(NSString *)clearToken completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/gate/verifyClearToken" body:@{ @"clearToken": clearToken ?: @"" } completion:completion];
}
- (void)gateSetClearToken:(NSString *)clearToken oldClearToken:(NSString *)oldClearToken completion:(AutumnOpsDictBlock)completion {
  NSMutableDictionary *b = [@{ @"clearToken": clearToken ?: @"" } mutableCopy];
  if (oldClearToken.length) b[@"oldClearToken"] = oldClearToken;
  [self _authedPost:@"/ops/api/v1/gate/setClearToken" body:b completion:completion];
}
- (void)gateSetAdminIpEnable:(BOOL)enable clearToken:(NSString *)clearToken completion:(AutumnOpsDictBlock)completion {
  NSMutableDictionary *b = [@{ @"enable": @(enable) } mutableCopy];
  if (clearToken.length) b[@"clearToken"] = clearToken;
  [self _authedPost:@"/ops/api/v1/gate/setAdminIpEnable" body:b completion:completion];
}
- (void)gateSetDiscoverEnabled:(BOOL)enable completion:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/gate/setDiscoverEnabled" body:@{ @"enable": @(enable) } completion:completion];
}

- (void)certList:(AutumnOpsDictBlock)completion {
  [self _authedPost:@"/ops/api/v1/cert/list" body:@{} completion:completion];
}
- (void)certIssueWithLabel:(NSString *)label completion:(AutumnOpsClaimBlock)completion {
  [self _authedPost:@"/ops/api/v1/cert/issue" body:@{ @"label": label ?: @"ops-device" } completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(nil, error); return; }
    completion([AutumnOpsClaimIssueResult fromJSON:data], nil);
  }];
}
- (void)certRevoke:(NSString *)certId completion:(AutumnOpsRevokeBlock)completion {
  [self _authedPost:@"/ops/api/v1/cert/revoke" body:@{ @"certId": certId ?: @"" } completion:^(NSDictionary *data, NSError *error) {
    if (error) { completion(nil, error); return; }
    completion([AutumnOpsRevokeResult fromJSON:data], nil);
  }];
}

- (AutumnOpsCredentialBundle *)currentBundle:(NSError **)error {
  return [self _loadBundle:error];
}
- (NSString *)exportWrappedWithPassphrase:(NSString *)passphrase error:(NSError **)error {
  AutumnOpsCredentialBundle *b = [self _loadBundle:error];
  if (!b) return nil;
  return [AutumnOpsStore exportPassphraseWrapped:b passphrase:passphrase];
}
- (BOOL)importWrapped:(NSString *)wrappedB64 passphrase:(NSString *)passphrase error:(NSError **)error {
  AutumnOpsCredentialBundle *b = [AutumnOpsStore importPassphraseWrapped:wrappedB64 passphrase:passphrase error:error];
  if (!b) return NO;
  if (![self.store save:b error:error]) return NO;
  _bundle = b;
  _sessionId = nil;
  return YES;
}

@end
