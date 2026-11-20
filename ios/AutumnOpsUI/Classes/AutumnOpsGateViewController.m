#import "AutumnOpsGateViewController.h"
#import "AutumnOpsManageViewController.h"
#import "AutumnOpsAddSiteViewController.h"
#import "AutumnOpsSitesViewController.h"
#import "AutumnOpsPageChromeView.h"
#import "AutumnOpsUIConfig.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>

@interface AutumnOpsGateViewController ()
@property (nonatomic, copy, nullable) NSDictionary *content;
@property (nonatomic, copy, nullable) NSString *rawURL;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITextField *passField;
@property (nonatomic, strong) UIButton *importBtn;
@property (nonatomic, strong) UIButton *addBtn;
@property (nonatomic, strong) UIButton *sitesBtn;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong, nullable) AutumnOpsPayload *payload;
@property (nonatomic, copy, nullable) NSString *discoverBase;
@property (nonatomic, strong, nullable) AutumnOpsProbeOutcome *probeOutcome;
@property (nonatomic, strong) AutumnOpsSiteStore *siteStore;
@property (nonatomic, strong, nullable) AutumnOpsPageChromeView *pageChrome;
@property (nonatomic, strong) UIStackView *bodyStack;
@end

@implementation AutumnOpsGateViewController

+ (instancetype)fromContent:(NSDictionary *)content {
  AutumnOpsGateViewController *vc = [AutumnOpsGateViewController new];
  vc.content = content;
  return vc;
}

+ (instancetype)discoverWithRawURL:(NSString *)rawURL {
  AutumnOpsGateViewController *vc = [AutumnOpsGateViewController new];
  vc.rawURL = rawURL;
  return vc;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  BOOL isPayload = self.rawURL.length == 0;
  NSString *title = isPayload ? @"导入运维凭证" : @"Autumn 运维发现";
  self.title = title;
  self.siteStore = [[AutumnOpsSiteStore alloc] initWithRootDirectory:[AutumnOpsSiteStore defaultRootDirectory]];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"站点列表" style:UIBarButtonItemStylePlain target:self action:@selector(_openSites)];

  BOOL embed = [AutumnOpsPageChromeView shouldEmbedInViewController:self];
  UIView *top = nil;
  if (embed) {
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = nil;
    _pageChrome = [AutumnOpsPageChromeView new];
    _pageChrome.titleText = title;
    _pageChrome.showsBack = YES;
    __weak typeof(self) weakSelf = self;
    _pageChrome.onBack = ^{ [AutumnOpsPageChromeView performBackFromViewController:weakSelf]; };
    UIButton *sites = [UIButton buttonWithType:UIButtonTypeSystem];
    [sites setTitle:@"站点列表" forState:UIControlStateNormal];
    sites.titleLabel.font = [UIFont systemFontOfSize:16];
    [sites addTarget:self action:@selector(_openSites) forControlEvents:UIControlEventTouchUpInside];
    [_pageChrome.rightStack addArrangedSubview:sites];
    [self.view addSubview:_pageChrome];
    [_pageChrome mas_makeConstraints:^(MASConstraintMaker *make) {
      make.left.right.equalTo(self.view);
      make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
      make.height.mas_equalTo(44);
    }];
    top = _pageChrome;
  }

  _statusLabel = [UILabel new];
  _statusLabel.numberOfLines = 0;
  _statusLabel.font = [UIFont systemFontOfSize:15];
  _passField = [UITextField new];
  _passField.borderStyle = UITextBorderStyleRoundedRect;
  _passField.secureTextEntry = YES;
  _passField.placeholder = @"分享口令";
  _passField.hidden = YES;
  _importBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [_importBtn setTitle:@"导入并进入" forState:UIControlStateNormal];
  _importBtn.hidden = YES;
  [_importBtn addTarget:self action:@selector(_importTapped) forControlEvents:UIControlEventTouchUpInside];
  _addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [_addBtn setTitle:@"继续添加 / 入驻" forState:UIControlStateNormal];
  _addBtn.hidden = YES;
  [_addBtn addTarget:self action:@selector(_addSite) forControlEvents:UIControlEventTouchUpInside];
  _sitesBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [_sitesBtn setTitle:@"打开站点列表" forState:UIControlStateNormal];
  _sitesBtn.hidden = YES;
  [_sitesBtn addTarget:self action:@selector(_openSites) forControlEvents:UIControlEventTouchUpInside];
  _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];

  _bodyStack = [[UIStackView alloc] initWithArrangedSubviews:@[_statusLabel, _passField, _importBtn, _addBtn, _sitesBtn, _spinner]];
  _bodyStack.axis = UILayoutConstraintAxisVertical;
  _bodyStack.spacing = 12;
  [self.view addSubview:_bodyStack];
  [_bodyStack mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.equalTo(self.view).inset(20);
    if (top) make.top.equalTo(top.mas_bottom).offset(24);
    else make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(24);
  }];

  dispatch_async(dispatch_get_main_queue(), ^{ [self _bootstrap]; });
}

- (void)_setStatus:(NSString *)s { self.statusLabel.text = s; }

- (void)_openSites {
  NSMutableArray *stack = [(self.navigationController.viewControllers ?: @[]) mutableCopy];
  while (stack.count > 1) [stack removeLastObject];
  [stack addObject:[AutumnOpsSitesViewController new]];
  [self.navigationController setViewControllers:stack animated:YES];
}

- (void)_pushManageSite:(AutumnOpsSiteEntry *)site {
  AutumnOpsManageViewController *vc = [[AutumnOpsManageViewController alloc] initWithSiteEntry:site siteStore:self.siteStore];
  NSMutableArray *stack = [(self.navigationController.viewControllers ?: @[]) mutableCopy];
  if (stack.count) [stack removeLastObject];
  [stack addObject:vc];
  [self.navigationController setViewControllers:stack animated:YES];
}

- (void)_bootstrap {
  [self.spinner startAnimating];
  if (self.content) {
    [self _startPayload];
    return;
  }
  if (self.rawURL.length) {
    [self _startDiscover:self.rawURL];
    return;
  }
  [self.spinner stopAnimating];
  [self _setStatus:@"无入口参数"];
}

- (void)_startPayload {
  [self _setStatus:@"正在读取运维凭证…"];
  AutumnOpsParseResult *parsed = [AutumnOpsParseResult fromMessageMap:self.content];
  if (!parsed.ok) {
    [self.spinner stopAnimating];
    [self _setStatus:parsed.error ?: @"无法解析运维凭证"];
    return;
  }
  self.payload = parsed.payload;
  NSString *certId = [self.payload.certId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
  if (certId.length) {
    AutumnOpsSiteEntry *hit = [self.siteStore findByCertId:certId];
    if (hit && [self.siteStore hasLocalCredential:hit]) {
      [self.spinner stopAnimating];
      [self _pushManageSite:hit];
      return;
    }
  }
  NSString *baseHint = [self.payload.baseUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
  if (baseHint.length && certId.length) {
    AutumnOpsSiteEntry *byBase = [self.siteStore findByBaseUrl:baseHint];
    if (byBase && byBase.certId.length && [byBase.certId isEqualToString:certId] && [self.siteStore hasLocalCredential:byBase]) {
      [self.spinner stopAnimating];
      [self _pushManageSite:byBase];
      return;
    }
  }
  [self.spinner stopAnimating];
  if (!baseHint.length) {
    [self _setStatus:@"凭证未含站点地址，请改用「添加站点」流程"];
    self.addBtn.hidden = NO;
    return;
  }
  [self _setStatus:@"需要分享口令以导入运维证书"];
  self.passField.hidden = NO;
  self.importBtn.hidden = NO;
}

- (void)_importTapped {
  NSString *pass = [self.passField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  AutumnOpsValidateResult *vr = [AutumnOpsValidators sharePassphrase:pass];
  if (!vr.ok) { [self _setStatus:vr.error]; return; }
  NSString *base = [AutumnOpsSiteEntry normalizeBaseUrl:self.payload.baseUrl ?: @""];
  if (!base.length) {
    [self _setStatus:@"凭证未含站点地址，请改用「添加站点」流程"];
    return;
  }
  [self.spinner startAnimating];
  [self _setStatus:@"正在导入并校验…"];
  NSString *tmpId = [NSUUID UUID].UUIDString;
  AutumnOpsSiteEntry *site = [self.siteStore findByBaseUrl:base];
  if (!site) {
    site = [AutumnOpsSiteEntry new];
    site.id = tmpId;
    site.title = base;
    site.baseUrl = base;
  }
  AutumnOpsStore *cred = [self.siteStore credentialStoreForSite:site];
  AutumnOpsClient *client = [[AutumnOpsClient alloc] initWithBaseUrl:base store:cred];
  client.deviceLabel = AutumnOpsUIConfig.deviceLabel;
  NSError *err = nil;
  if (![client importWrapped:self.payload.wrapped passphrase:pass error:&err]) {
    [self.spinner stopAnimating];
    [self _setStatus:[NSString stringWithFormat:@"导入失败：%@", err.localizedDescription ?: @"未知错误"]];
    return;
  }
  AutumnOpsCredentialBundle *bundle = [client currentBundle:nil];
  if (!bundle) {
    [cred clear:nil];
    [self.spinner stopAnimating];
    [self _setStatus:@"导入失败：未读到本机证书包"];
    return;
  }
  AutumnOpsSiteEntry *byCert = [self.siteStore findByCertId:bundle.certId];
  if (byCert && ![byCert.id isEqualToString:site.id]) {
    if ([site.id isEqualToString:tmpId]) [cred clear:nil];
    site = byCert;
    AutumnOpsStore *mergeCred = [self.siteStore credentialStoreForSite:site];
    AutumnOpsClient *mergeClient = [[AutumnOpsClient alloc] initWithBaseUrl:site.baseUrl store:mergeCred];
    mergeClient.deviceLabel = AutumnOpsUIConfig.deviceLabel;
    if (![mergeClient importWrapped:self.payload.wrapped passphrase:pass error:&err]) {
      [self.spinner stopAnimating];
      [self _setStatus:err.localizedDescription ?: @"合并导入失败"];
      return;
    }
    [mergeClient ensureSession:^(NSError *error) {
      [self.spinner stopAnimating];
      if (error) {
        [self _setStatus:error.localizedDescription];
        return;
      }
      site.siteId = bundle.siteId.length ? bundle.siteId : site.siteId;
      site.certId = bundle.certId;
      site.serverFingerprint = bundle.serverFingerprint ?: self.payload.serverFingerprint;
      site.enrolled = YES;
      [self.siteStore upsertSite:site error:nil];
      [self _pushManageSite:site];
    }];
    return;
  }
  NSString *fileFp = self.payload.serverFingerprint ?: bundle.serverFingerprint;
  AutumnOpsEndpointPlan *plan = [AutumnOpsEndpoint resolve:base];
  [AutumnOpsEndpoint probePlan:plan store:cred hasLocalCert:YES completion:^(AutumnOpsResolvedProbe *resolved) {
    NSString *probeFp = resolved.outcome.result.serverFingerprint;
    if (probeFp.length && fileFp.length && ![probeFp isEqualToString:fileFp]) {
      [cred clear:nil];
      [self.spinner stopAnimating];
      [self _setStatus:@"凭证与站点指纹不一致，已取消。请确认是否为同一 Autumn 实例。"];
      return;
    }
    [client ensureSession:^(NSError *error) {
      [self.spinner stopAnimating];
      if (error) {
        [cred clear:nil];
        [self _setStatus:[NSString stringWithFormat:@"导入失败：%@", error.localizedDescription]];
        return;
      }
      site.siteId = bundle.siteId.length ? bundle.siteId : site.siteId;
      site.certId = bundle.certId;
      site.serverFingerprint = fileFp;
      site.enrolled = YES;
      if (!site.title.length) site.title = base;
      [self.siteStore upsertSite:site error:nil];
      [self _pushManageSite:site];
    }];
  }];
}

- (void)_startDiscover:(NSString *)raw {
  NSString *base = [AutumnOpsDiscover tryParseBaseUrl:raw] ?: [AutumnOpsDiscover tryParseBaseUrl:raw forceHttpBase:YES];
  if (!base.length) {
    [self.spinner stopAnimating];
    [self _setStatus:@"无法识别运维发现地址"];
    return;
  }
  self.discoverBase = base;
  [self _setStatus:[NSString stringWithFormat:@"正在探测 %@ …", base]];
  AutumnOpsSiteEntry *existing = [self.siteStore findByBaseUrl:base];
  if (existing.enrolled && [self.siteStore hasLocalCredential:existing]) {
    [self.spinner stopAnimating];
    [self _pushManageSite:existing];
    return;
  }
  AutumnOpsSiteEntry *tmp = existing ?: ({
    AutumnOpsSiteEntry *e = [AutumnOpsSiteEntry new];
    e.id = @"tmp";
    e.title = @"";
    e.baseUrl = base;
    e;
  });
  AutumnOpsStore *probeStore = [self.siteStore credentialStoreForSite:tmp];
  BOOL hasCert = [probeStore load:nil] != nil;
  AutumnOpsEndpointPlan *plan = [AutumnOpsEndpoint resolve:base];
  [AutumnOpsEndpoint probePlan:plan store:probeStore hasLocalCert:hasCert completion:^(AutumnOpsResolvedProbe *resolved) {
    [self.spinner stopAnimating];
    NSString *effective = resolved.baseUrl.length ? resolved.baseUrl : base;
    self.discoverBase = effective;
    self.probeOutcome = resolved.outcome;
    if (resolved.outcome.kind == AutumnOpsProbeKindReady && hasCert) {
      AutumnOpsSiteEntry *site = existing ?: [self.siteStore findByBaseUrl:effective];
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
        [self.siteStore upsertSite:site error:nil];
      }
      [self _pushManageSite:site];
      return;
    }
    NSMutableString *msg = [NSMutableString stringWithString:resolved.outcome.message ?: @""];
    if (resolved.outcome.nextStep.length) {
      [msg appendFormat:@"\n%@", resolved.outcome.nextStep];
    }
    [self _setStatus:msg];
    self.addBtn.hidden = NO;
    self.sitesBtn.hidden = NO;
  }];
}

- (void)_addSite {
  AutumnOpsAddSiteViewController *vc = [[AutumnOpsAddSiteViewController alloc] initWithPresetBaseURL:self.discoverBase autoProbe:YES];
  [self.navigationController pushViewController:vc animated:YES];
}

@end
