#import "AutumnOpsAddSiteViewController.h"
#import "AutumnOpsManageViewController.h"
#import "AutumnOpsRecoveryViewController.h"
#import "AutumnOpsUIConfig.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface AutumnOpsAddSiteViewController () <UIDocumentPickerDelegate>
@property (nonatomic, copy, nullable) NSString *presetBase;
@property (nonatomic) BOOL autoProbe;
@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextField *endpointField;
@property (nonatomic, strong) UITextField *secretField;
@property (nonatomic, strong) UISegmentedControl *modeSeg;
@property (nonatomic, strong) UILabel *hint;
@property (nonatomic, strong) UILabel *probeLabel;
@property (nonatomic, strong, nullable) AutumnOpsProbeOutcome *outcome;
@property (nonatomic, copy, nullable) NSString *resolvedBase;
@property (nonatomic, strong) AutumnOpsSiteStore *siteStore;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation AutumnOpsAddSiteViewController

- (instancetype)initWithPresetBaseURL:(NSString *)baseURL autoProbe:(BOOL)autoProbe {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _presetBase = baseURL;
    _autoProbe = autoProbe;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  self.title = @"添加站点";
  self.siteStore = [[AutumnOpsSiteStore alloc] initWithRootDirectory:[AutumnOpsSiteStore defaultRootDirectory]];
  _titleField = [self _field:@"显示名称（可选）"];
  _endpointField = [self _field:@"域名 / IP / URL"];
  if (self.presetBase.length) _endpointField.text = self.presetBase;
  _secretField = [self _field:@"入驻口令 / 认领码 / 分享口令"];
  _secretField.secureTextEntry = YES;
  _modeSeg = [[UISegmentedControl alloc] initWithItems:@[@"首次口令", @"认领码", @"凭证文件"]];
  _modeSeg.selectedSegmentIndex = 0;
  [_modeSeg addTarget:self action:@selector(_modeChanged) forControlEvents:UIControlEventValueChanged];
  _hint = [UILabel new];
  _hint.numberOfLines = 0;
  _hint.font = [UIFont systemFontOfSize:13];
  _hint.textColor = UIColor.secondaryLabelColor;
  _probeLabel = [UILabel new];
  _probeLabel.numberOfLines = 0;
  _probeLabel.font = [UIFont systemFontOfSize:13];
  _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  UIButton *probe = [UIButton buttonWithType:UIButtonTypeSystem];
  [probe setTitle:@"探测" forState:UIControlStateNormal];
  [probe addTarget:self action:@selector(_probe) forControlEvents:UIControlEventTouchUpInside];
  UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
  [go setTitle:@"继续" forState:UIControlStateNormal];
  [go addTarget:self action:@selector(_go) forControlEvents:UIControlEventTouchUpInside];
  UIButton *recovery = [UIButton buttonWithType:UIButtonTypeSystem];
  [recovery setTitle:@"丢钥恢复说明" forState:UIControlStateNormal];
  [recovery addTarget:self action:@selector(_recovery) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_modeSeg, _titleField, _endpointField, probe, _spinner, _probeLabel, _secretField, _hint, go, recovery]];
  stack.axis = UILayoutConstraintAxisVertical;
  stack.spacing = 12;
  [self.view addSubview:stack];
  [stack mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.equalTo(self.view).inset(20);
    make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(20);
  }];
  [self _modeChanged];
  if (self.autoProbe && self.presetBase.length) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self _probe]; });
  }
}

- (UITextField *)_field:(NSString *)ph {
  UITextField *f = [UITextField new];
  f.borderStyle = UITextBorderStyleRoundedRect;
  f.placeholder = ph;
  return f;
}

- (void)_modeChanged {
  NSInteger i = self.modeSeg.selectedSegmentIndex;
  self.secretField.hidden = (i == 2);
  if (i == 0) self.hint.text = @"从服务器日志复制 OpsEnroll secret=";
  else if (i == 1) self.hint.text = @"粘贴其它已登录设备签发的认领码";
  else self.hint.text = @"选择 .autumnops / json 凭证后输入分享口令";
}

- (void)_recovery {
  AutumnOpsRecoveryViewController *vc = [[AutumnOpsRecoveryViewController alloc] initWithSiteTitle:self.titleField.text baseUrl:self.resolvedBase ?: self.endpointField.text];
  [self.navigationController pushViewController:vc animated:YES];
}

- (void)_probe {
  AutumnOpsValidateResult *titleOk = [AutumnOpsValidators siteTitle:self.titleField.text];
  if (!titleOk.ok) { self.probeLabel.text = titleOk.error; return; }
  AutumnOpsValidateResult *ep = [AutumnOpsValidators siteEndpoint:self.endpointField.text];
  if (!ep.ok) { self.probeLabel.text = ep.error; return; }
  AutumnOpsEndpointPlan *plan = [AutumnOpsEndpoint resolve:self.endpointField.text];
  AutumnOpsSiteEntry *tmp = [AutumnOpsSiteEntry new];
  tmp.id = @"tmp";
  tmp.baseUrl = plan.candidates.firstObject ?: self.endpointField.text;
  AutumnOpsStore *store = [self.siteStore credentialStoreForSite:tmp];
  BOOL hasCert = [store load:nil] != nil;
  [self.spinner startAnimating];
  self.probeLabel.text = @"探测中…";
  [AutumnOpsEndpoint probePlan:plan store:store hasLocalCert:hasCert completion:^(AutumnOpsResolvedProbe *resolved) {
    [self.spinner stopAnimating];
    self.outcome = resolved.outcome;
    self.resolvedBase = resolved.baseUrl.length ? resolved.baseUrl : tmp.baseUrl;
    if (self.resolvedBase.length) self.endpointField.text = self.resolvedBase;
    NSMutableString *t = [NSMutableString stringWithFormat:@"%@\n%@", resolved.outcome.message ?: @"", resolved.outcome.nextStep ?: @""];
    if (resolved.tried.count > 1) [t appendFormat:@"\n尝试：%@", [resolved.tried componentsJoinedByString:@" → "]];
    self.probeLabel.text = t;
    if (resolved.outcome.kind == AutumnOpsProbeKindNeedReset) {
      self.modeSeg.selectedSegmentIndex = 2;
      [self _modeChanged];
    } else if (resolved.outcome.kind == AutumnOpsProbeKindReady && hasCert) {
      AutumnOpsSiteEntry *existing = [self.siteStore findByBaseUrl:self.resolvedBase];
      if (existing && [self.siteStore hasLocalCredential:existing]) {
        UIButton *enter = [UIButton buttonWithType:UIButtonTypeSystem];
        [enter setTitle:@"本机已有证书 · 直接进入管理" forState:UIControlStateNormal];
        [enter addTarget:self action:@selector(_enterExisting) forControlEvents:UIControlEventTouchUpInside];
        // attach once via associated — simplify: just push
        [self.navigationController pushViewController:[[AutumnOpsManageViewController alloc] initWithSiteEntry:existing siteStore:self.siteStore] animated:YES];
      }
    }
  }];
}

- (void)_enterExisting {
  AutumnOpsSiteEntry *existing = [self.siteStore findByBaseUrl:self.resolvedBase];
  if (existing) {
    [self.navigationController pushViewController:[[AutumnOpsManageViewController alloc] initWithSiteEntry:existing siteStore:self.siteStore] animated:YES];
  }
}

- (BOOL)_probeAllowsMode:(NSInteger)mode {
  if (!self.outcome) {
    self.hint.text = @"请先探测站点";
    return NO;
  }
  AutumnOpsProbeKind k = self.outcome.kind;
  if (mode == 0) { // enroll
    if (k != AutumnOpsProbeKindPending) {
      self.hint.text = @"当前探测结果不允许首次入驻（需 pending）";
      return NO;
    }
  } else if (mode == 1) { // claim
    if (k != AutumnOpsProbeKindReady && k != AutumnOpsProbeKindPending) {
      self.hint.text = @"当前探测结果不允许认领";
      return NO;
    }
  } else { // file
    if (k == AutumnOpsProbeKindNetwork || k == AutumnOpsProbeKindIncompatible || k == AutumnOpsProbeKindForbidden) {
      self.hint.text = @"探测失败，无法导入凭证";
      return NO;
    }
  }
  return YES;
}

- (void)_go {
  NSInteger mode = self.modeSeg.selectedSegmentIndex;
  if (mode != 2 && ![self _probeAllowsMode:mode]) return;
  if (mode == 2) {
    if (![self _probeAllowsMode:2]) return;
    UTType *t = [UTType typeWithFilenameExtension:@"autumnops"] ?: UTTypeJSON;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[t, UTTypeJSON]];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
    return;
  }
  AutumnOpsValidateResult *sec = mode == 0 ? [AutumnOpsValidators enrollSecret:self.secretField.text] : [AutumnOpsValidators claimSecret:self.secretField.text];
  if (!sec.ok) { self.hint.text = sec.error; return; }
  NSString *base = self.resolvedBase.length ? self.resolvedBase : [AutumnOpsEndpoint resolve:self.endpointField.text].candidates.firstObject;
  [self _enrollOrClaimBase:base mode:mode secret:self.secretField.text];
}

- (void)_enrollOrClaimBase:(NSString *)base mode:(NSInteger)mode secret:(NSString *)secret {
  AutumnOpsSiteEntry *existing = [self.siteStore findByBaseUrl:base];
  NSString *sid = existing.id.length ? existing.id : [NSUUID UUID].UUIDString;
  AutumnOpsSiteEntry *e = existing ?: [AutumnOpsSiteEntry new];
  e.id = sid;
  e.title = self.titleField.text.length ? self.titleField.text : base;
  e.baseUrl = base;
  AutumnOpsStore *store = [self.siteStore credentialStoreForSite:e];
  AutumnOpsClient *client = [[AutumnOpsClient alloc] initWithBaseUrl:base store:store];
  client.deviceLabel = AutumnOpsUIConfig.deviceLabel;
  self.hint.text = @"处理中…";
  void (^done)(AutumnOpsEnrollResult *, NSError *) = ^(AutumnOpsEnrollResult *result, NSError *error) {
    if (error) { self.hint.text = error.localizedDescription; return; }
    e.siteId = result.siteId;
    e.certId = result.certId;
    e.serverFingerprint = result.serverFingerprint;
    e.enrolled = YES;
    [self.siteStore upsertSite:e error:nil];
    [self.navigationController pushViewController:[[AutumnOpsManageViewController alloc] initWithSiteEntry:e siteStore:self.siteStore] animated:YES];
  };
  if (mode == 0) [client enrollWithSecret:secret completion:done];
  else [client claimWithSecret:secret completion:done];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  NSURL *url = urls.firstObject;
  [url startAccessingSecurityScopedResource];
  NSData *data = [NSData dataWithContentsOfURL:url];
  [url stopAccessingSecurityScopedResource];
  NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  AutumnOpsParseResult *parsed = [AutumnOpsParseResult parse:raw ?: @""];
  if (!parsed.ok) { self.hint.text = parsed.error; return; }
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"分享口令" message:nil preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.secureTextEntry = YES; }];
  __weak typeof(self) weakSelf = self;
  [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:@"导入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    NSString *pass = alert.textFields.firstObject.text;
    AutumnOpsValidateResult *vr = [AutumnOpsValidators sharePassphrase:pass];
    if (!vr.ok) { weakSelf.hint.text = vr.error; return; }
    NSString *base = weakSelf.resolvedBase.length ? weakSelf.resolvedBase : (parsed.payload.baseUrl ?: weakSelf.endpointField.text);
    base = [AutumnOpsSiteEntry normalizeBaseUrl:base];
    AutumnOpsSiteEntry *existing = [weakSelf.siteStore findByBaseUrl:base];
    AutumnOpsSiteEntry *e = existing ?: [AutumnOpsSiteEntry new];
    if (!existing) {
      e.id = [NSUUID UUID].UUIDString;
      e.title = weakSelf.titleField.text.length ? weakSelf.titleField.text : base;
      e.baseUrl = base;
    }
    AutumnOpsStore *store = [weakSelf.siteStore credentialStoreForSite:e];
    AutumnOpsClient *client = [[AutumnOpsClient alloc] initWithBaseUrl:base store:store];
    client.deviceLabel = AutumnOpsUIConfig.deviceLabel;
    NSError *err = nil;
    if (![client importWrapped:parsed.payload.wrapped passphrase:pass error:&err]) {
      weakSelf.hint.text = err.localizedDescription;
      return;
    }
    NSString *fileFp = parsed.payload.serverFingerprint;
    [AutumnOpsEndpoint probePlan:[AutumnOpsEndpoint resolve:base] store:store hasLocalCert:YES completion:^(AutumnOpsResolvedProbe *resolved) {
      NSString *probeFp = resolved.outcome.result.serverFingerprint;
      if (probeFp.length && fileFp.length && ![probeFp isEqualToString:fileFp]) {
        [store clear:nil];
        weakSelf.hint.text = @"凭证与站点指纹不一致，已取消";
        return;
      }
      AutumnOpsCredentialBundle *b = [client currentBundle:nil];
      e.siteId = b.siteId ?: parsed.payload.siteId;
      e.certId = b.certId ?: parsed.payload.certId;
      e.serverFingerprint = fileFp ?: b.serverFingerprint;
      e.enrolled = YES;
      e.baseUrl = resolved.baseUrl.length ? resolved.baseUrl : base;
      [weakSelf.siteStore upsertSite:e error:nil];
      [weakSelf.navigationController pushViewController:[[AutumnOpsManageViewController alloc] initWithSiteEntry:e siteStore:weakSelf.siteStore] animated:YES];
    }];
  }]];
  [self presentViewController:alert animated:YES completion:nil];
}

@end
