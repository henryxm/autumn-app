#import "AutumnOpsAddSiteViewController.h"
#import "AutumnOpsAddSectionView.h"
#import "AutumnOpsFusedActionBarView.h"
#import "AutumnOpsFusedFieldActionView.h"
#import "AutumnOpsManageViewController.h"
#import "AutumnOpsPageChromeView.h"
#import "AutumnOpsRecoveryViewController.h"
#import "AutumnOpsUIConfig.h"
#import "AutumnOpsUIControls.h"
#import "AutumnOpsUITheme.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>

static const void *kAutumnOpsPasteFieldKey = &kAutumnOpsPasteFieldKey;

typedef NS_ENUM(NSInteger, AutumnOpsAddMode) {
  AutumnOpsAddModeEnroll = 0,
  AutumnOpsAddModeClaim = 1,
  AutumnOpsAddModeImport = 2,
};

@interface AutumnOpsAddSiteViewController () <UIDocumentPickerDelegate, UIGestureRecognizerDelegate, UITextFieldDelegate>
@property (nonatomic, copy, nullable) NSString *presetBase;
@property (nonatomic) BOOL autoProbe;
@property (nonatomic, strong) AutumnOpsSiteStore *siteStore;
@property (nonatomic, strong, nullable) AutumnOpsPageChromeView *pageChrome;

@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *rootStack;

@property (nonatomic, strong) AutumnOpsAddSectionView *addressSection;
@property (nonatomic, strong) UIView *titleFieldWrap;
@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) AutumnOpsFusedFieldActionView *urlFused;

@property (nonatomic, strong) AutumnOpsAddSectionView *probeSection;
@property (nonatomic, strong) UIView *probeCard;
@property (nonatomic, strong) UIView *probeAccentBar;
@property (nonatomic, strong) UILabel *probeMessageLabel;
@property (nonatomic, strong) UILabel *probeNextLabel;
@property (nonatomic, strong) UILabel *probeBaseLabel;
@property (nonatomic, strong) UIButton *recoveryBtn;
@property (nonatomic, strong) UIButton *readyBtn;

@property (nonatomic, strong) AutumnOpsAddSectionView *joinSection;
@property (nonatomic, strong) UISegmentedControl *modeSeg;
@property (nonatomic, strong) UIStackView *joinBodyStack;

@property (nonatomic, strong) UILabel *enrollHint;
@property (nonatomic, strong) AutumnOpsFusedFieldActionView *enrollFused;
@property (nonatomic, strong) UILabel *enrollBlockedHint;
@property (nonatomic, strong) UIView *enrollBody;

@property (nonatomic, strong) UILabel *claimHint;
@property (nonatomic, strong) AutumnOpsFusedFieldActionView *claimFused;
@property (nonatomic, strong) UIView *claimBody;

@property (nonatomic, strong) UILabel *importHint;
@property (nonatomic, strong) AutumnOpsFusedActionBarView *pickBar;
@property (nonatomic, strong) UILabel *pickedBaseLabel;
@property (nonatomic, strong) AutumnOpsFusedFieldActionView *importPassFused;
@property (nonatomic, strong) UIView *importBody;

@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong, nullable) AutumnOpsProbeOutcome *outcome;
@property (nonatomic, copy, nullable) NSString *resolvedBase;
@property (nonatomic) BOOL busy;
@property (nonatomic) AutumnOpsAddMode mode;
@property (nonatomic, strong, nullable) AutumnOpsPayload *pickedCredential;
@property (nonatomic, copy, nullable) NSString *pickedCredentialName;
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
  self.mode = AutumnOpsAddModeEnroll;
  _pageChrome = [AutumnOpsPageChromeView installOnViewController:self title:@"添加站点" rightItems:nil];

  _scroll = [UIScrollView new];
  _scroll.alwaysBounceVertical = YES;
  _scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  _scroll.delaysContentTouches = NO;
  [self.view addSubview:_scroll];

  // 点输入框以外收起键盘；点在 UITextField 上不拦截（避免抢焦点）
  UITapGestureRecognizer *dismissTap =
      [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_dismissKeyboard)];
  dismissTap.cancelsTouchesInView = NO;
  dismissTap.delegate = self;
  [_scroll addGestureRecognizer:dismissTap];

  _rootStack = [UIStackView new];
  _rootStack.axis = UILayoutConstraintAxisVertical;
  _rootStack.spacing = 12;
  _rootStack.alignment = UIStackViewAlignmentFill;
  [_scroll addSubview:_rootStack];

  [_scroll mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.bottom.equalTo(self.view);
    if (_pageChrome) make.top.equalTo(_pageChrome.mas_bottom);
    else make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
  }];
  [_rootStack mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_scroll).insets(UIEdgeInsetsMake(12, 16, 28, 16));
    make.width.equalTo(_scroll).offset(-32);
  }];

  [self _buildAddressSection];
  [self _buildProbeSection];
  [self _buildJoinSection];

  _statusLabel = [UILabel new];
  _statusLabel.numberOfLines = 0;
  _statusLabel.font = [UIFont systemFontOfSize:13];
  _statusLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;
  _statusLabel.hidden = YES;
  [_rootStack addArrangedSubview:_statusLabel];

  [self _refreshSections];

  if (self.presetBase.length) {
    self.urlFused.textField.text = self.presetBase;
  }
  if (self.autoProbe && self.presetBase.length) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self _probe]; });
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  if (self.pageChrome) {
    self.pageChrome.showsBack = [AutumnOpsPageChromeView canGoBackFromViewController:self];
  }
}

#pragma mark - Build UI

- (UIView *)_outlinedFieldWrap:(UITextField *)field {
  UIView *wrap = [UIView new];
  wrap.backgroundColor = AutumnOpsUITheme.surface;
  wrap.layer.cornerRadius = 12;
  wrap.clipsToBounds = YES;
  [AutumnOpsUITheme applyBorderToLayer:wrap.layer color:AutumnOpsUITheme.outlineVariant width:1];
  [wrap addSubview:field];
  field.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [wrap.heightAnchor constraintEqualToConstant:52],
    [field.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:14],
    [field.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-14],
    [field.topAnchor constraintEqualToAnchor:wrap.topAnchor],
    [field.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor],
  ]];
  return wrap;
}

- (UIButton *)_pasteButtonForField:(UITextField *)field {
  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
  UIImageSymbolConfiguration *cfg =
      [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
  [btn setImage:[UIImage systemImageNamed:@"doc.on.clipboard" withConfiguration:cfg] forState:UIControlStateNormal];
  btn.tintColor = AutumnOpsUITheme.onSurfaceVariant;
  btn.accessibilityLabel = @"从剪贴板粘贴";
  [btn addTarget:self action:@selector(_pasteTapped:) forControlEvents:UIControlEventTouchUpInside];
  objc_setAssociatedObject(btn, kAutumnOpsPasteFieldKey, field, OBJC_ASSOCIATION_ASSIGN);
  return btn;
}

- (void)_buildAddressSection {
  _addressSection = [[AutumnOpsAddSectionView alloc] initWithTitle:@"1. 站点地址"
      subtitle:@"域名优先 https 再 http；IP（含内网）用 http。已写协议则不再自动拼接。"];

  _titleField = [UITextField new];
  _titleField.borderStyle = UITextBorderStyleNone;
  _titleField.font = [UIFont systemFontOfSize:15];
  _titleField.textColor = AutumnOpsUITheme.onSurface;
  _titleField.attributedPlaceholder = [[NSAttributedString alloc]
      initWithString:@"显示名称（选填，如：生产机房）"
          attributes:@{NSForegroundColorAttributeName : [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.7]}];
  _titleField.returnKeyType = UIReturnKeyNext;
  _titleField.delegate = self;
  _titleFieldWrap = [self _outlinedFieldWrap:_titleField];

  _urlFused = [[AutumnOpsFusedFieldActionView alloc] initWithHint:@"域名或 IP，如 example.com / 192.168.1.10"
                                                      actionTitle:@"探测"
                                                           target:self
                                                           action:@selector(_probe)];
  _urlFused.textField.keyboardType = UIKeyboardTypeURL;
  _urlFused.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  _urlFused.textField.autocorrectionType = UITextAutocorrectionTypeNo;
  _urlFused.textField.returnKeyType = UIReturnKeyGo;
  _urlFused.textField.delegate = self;
  [_urlFused.textField addTarget:self action:@selector(_urlChanged) forControlEvents:UIControlEventEditingChanged];

  [_addressSection.contentStack addArrangedSubview:_titleFieldWrap];
  [_addressSection.contentStack addArrangedSubview:_urlFused];
  [_rootStack addArrangedSubview:_addressSection];
}

- (void)_buildProbeSection {
  _probeSection = [[AutumnOpsAddSectionView alloc] initWithTitle:@"2. 探测结果" subtitle:nil];
  _probeSection.hidden = YES;

  _probeCard = [UIView new];
  _probeCard.layer.cornerRadius = 12;
  _probeCard.clipsToBounds = YES;

  _probeAccentBar = [UIView new];
  _probeAccentBar.layer.cornerRadius = 2;

  _probeMessageLabel = [UILabel new];
  _probeMessageLabel.numberOfLines = 0;
  _probeMessageLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
  _probeMessageLabel.textColor = AutumnOpsUITheme.onSurface;

  _probeNextLabel = [UILabel new];
  _probeNextLabel.numberOfLines = 0;
  _probeNextLabel.font = [UIFont systemFontOfSize:13];
  _probeNextLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;

  _probeBaseLabel = [UILabel new];
  _probeBaseLabel.numberOfLines = 0;
  _probeBaseLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  _probeBaseLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;

  UIStackView *textCol = [[UIStackView alloc] initWithArrangedSubviews:@[_probeMessageLabel, _probeNextLabel, _probeBaseLabel]];
  textCol.axis = UILayoutConstraintAxisVertical;
  textCol.spacing = 4;
  textCol.alignment = UIStackViewAlignmentFill;
  [textCol setCustomSpacing:6 afterView:_probeNextLabel];

  UIStackView *cardRow = [[UIStackView alloc] initWithArrangedSubviews:@[_probeAccentBar, textCol]];
  cardRow.axis = UILayoutConstraintAxisHorizontal;
  cardRow.spacing = 10;
  cardRow.alignment = UIStackViewAlignmentTop;
  [_probeCard addSubview:cardRow];
  cardRow.translatesAutoresizingMaskIntoConstraints = NO;
  [_probeAccentBar.widthAnchor constraintEqualToConstant:4].active = YES;
  [_probeAccentBar.heightAnchor constraintEqualToConstant:40].active = YES;
  [NSLayoutConstraint activateConstraints:@[
    [cardRow.topAnchor constraintEqualToAnchor:_probeCard.topAnchor constant:12],
    [cardRow.leadingAnchor constraintEqualToAnchor:_probeCard.leadingAnchor constant:12],
    [cardRow.trailingAnchor constraintEqualToAnchor:_probeCard.trailingAnchor constant:-12],
    [cardRow.bottomAnchor constraintEqualToAnchor:_probeCard.bottomAnchor constant:-12],
  ]];

  _recoveryBtn = [AutumnOpsUIControls buttonWithTitle:@"无凭证时的恢复步骤"
                                                style:AutumnOpsButtonStyleOutlined
                                               target:self
                                               action:@selector(_recovery)];
  _recoveryBtn.hidden = YES;

  _readyBtn = [AutumnOpsUIControls buttonWithTitle:@"本机已有证书 · 直接进入管理"
                                             style:AutumnOpsButtonStyleTonal
                                            target:self
                                            action:@selector(_saveReadyAndOpen)];
  _readyBtn.hidden = YES;

  [_probeSection.contentStack addArrangedSubview:_probeCard];
  [_probeSection.contentStack addArrangedSubview:_recoveryBtn];
  [_probeSection.contentStack addArrangedSubview:_readyBtn];
  [_rootStack addArrangedSubview:_probeSection];
}

- (void)_buildJoinSection {
  _joinSection = [[AutumnOpsAddSectionView alloc] initWithTitle:@"3. 接入方式"
      subtitle:@"按你的情况选一种：首次 / 认领新设备 / 导入凭证。"];
  _joinSection.hidden = YES;

  _modeSeg = [[UISegmentedControl alloc] initWithItems:@[@"首次", @"认领码", @"凭证"]];
  _modeSeg.selectedSegmentIndex = 0;
  [_modeSeg addTarget:self action:@selector(_modeChanged) forControlEvents:UIControlEventValueChanged];

  _joinBodyStack = [UIStackView new];
  _joinBodyStack.axis = UILayoutConstraintAxisVertical;
  _joinBodyStack.spacing = 10;
  _joinBodyStack.alignment = UIStackViewAlignmentFill;

  // enroll
  _enrollHint = [self _hintLabel:@"从服务器控制台日志复制「OpsEnroll secret=」后的口令。"];
  _enrollFused = [[AutumnOpsFusedFieldActionView alloc] initWithHint:@"入驻口令"
                                                         actionTitle:@"入驻"
                                                              target:self
                                                              action:@selector(_enrollAndOpen)];
  [_enrollFused setObscure:YES];
  _enrollFused.textField.returnKeyType = UIReturnKeyDone;
  _enrollFused.textField.delegate = self;
  [_enrollFused setTrailing:[self _pasteButtonForField:_enrollFused.textField]];
  _enrollBlockedHint = [self _hintLabel:@"当前不可首次入驻。已有管理员设备 →「认领码」；同证共享 →「导入凭证」。"];
  _enrollBlockedHint.hidden = YES;
  _enrollBody = [self _wrapViews:@[_enrollHint, _enrollFused, _enrollBlockedHint]];

  // claim
  _claimHint = [self _hintLabel:@"粘贴已登录设备「证书」页签发的认领码（文字，约 30 分钟）。不是运维密钥消息。"];
  _claimFused = [[AutumnOpsFusedFieldActionView alloc] initWithHint:@"认领码"
                                                        actionTitle:@"认领"
                                                             target:self
                                                             action:@selector(_claimAndOpen)];
  _claimFused.textField.returnKeyType = UIReturnKeyDone;
  _claimFused.textField.delegate = self;
  [_claimFused setTrailing:[self _pasteButtonForField:_claimFused.textField]];
  _claimBody = [self _wrapViews:@[_claimHint, _claimFused]];

  // import
  _importHint = [self _hintLabel:@"选择他机导出的运维凭证文件，再填导出时的分享口令。给同事新设备请用「认领码」。"
                                @"宿主聊天会话请点开 AutumnOps 运维卡导入。"];
  _pickBar = [[AutumnOpsFusedActionBarView alloc] initWithIconSystemName:@"folder"
                                                             actionTitle:@"选文件"
                                                                  target:self
                                                                  action:@selector(_pickCredentialFile)];
  [_pickBar setLabelText:@"尚未选择运维凭证" selected:NO];
  _pickedBaseLabel = [UILabel new];
  _pickedBaseLabel.numberOfLines = 0;
  _pickedBaseLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  _pickedBaseLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;
  _pickedBaseLabel.hidden = YES;
  _importPassFused = [[AutumnOpsFusedFieldActionView alloc] initWithHint:@"分享口令（与导出时相同）"
                                                             actionTitle:@"导入"
                                                                  target:self
                                                                  action:@selector(_importCredentialAndOpen)];
  [_importPassFused setObscure:YES];
  _importPassFused.textField.returnKeyType = UIReturnKeyDone;
  _importPassFused.textField.delegate = self;
  _importBody = [self _wrapViews:@[_importHint, _pickBar, _pickedBaseLabel, _importPassFused]];

  [_joinBodyStack addArrangedSubview:_enrollBody];
  [_joinBodyStack addArrangedSubview:_claimBody];
  [_joinBodyStack addArrangedSubview:_importBody];

  [_joinSection.contentStack addArrangedSubview:_modeSeg];
  [_joinSection.contentStack addArrangedSubview:_joinBodyStack];
  [_rootStack addArrangedSubview:_joinSection];

  [self _modeChanged];
}

- (UILabel *)_hintLabel:(NSString *)text {
  UILabel *l = [UILabel new];
  l.numberOfLines = 0;
  NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
  ps.lineHeightMultiple = 1.4;
  l.attributedText = [[NSAttributedString alloc] initWithString:text
      attributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:12],
        NSForegroundColorAttributeName : AutumnOpsUITheme.onSurfaceVariant,
        NSParagraphStyleAttributeName : ps,
      }];
  return l;
}

- (UIView *)_wrapViews:(NSArray<UIView *> *)views {
  UIStackView *s = [[UIStackView alloc] initWithArrangedSubviews:views];
  s.axis = UILayoutConstraintAxisVertical;
  s.spacing = 10;
  s.alignment = UIStackViewAlignmentFill;
  return s;
}

#pragma mark - State

- (BOOL)_canEnroll {
  return self.outcome.kind == AutumnOpsProbeKindPending;
}

- (BOOL)_canClaim {
  AutumnOpsProbeKind k = self.outcome.kind;
  return k == AutumnOpsProbeKindPending || k == AutumnOpsProbeKindReady || k == AutumnOpsProbeKindNeedReset;
}

- (BOOL)_canImport {
  return [self _canClaim];
}

- (BOOL)_showJoin {
  return self.outcome != nil && ([self _canEnroll] || [self _canClaim] || [self _canImport]);
}

- (UIColor *)_accentForKind:(AutumnOpsProbeKind)kind {
  switch (kind) {
    case AutumnOpsProbeKindPending:
    case AutumnOpsProbeKindReady:
      return AutumnOpsUITheme.tertiary;
    case AutumnOpsProbeKindNeedReset:
      return AutumnOpsUITheme.secondary;
    case AutumnOpsProbeKindForbidden:
    case AutumnOpsProbeKindIncompatible:
    case AutumnOpsProbeKindNetwork:
    default:
      return AutumnOpsUITheme.error;
  }
}

- (void)_setStatus:(NSString *)text {
  self.statusLabel.text = text;
  self.statusLabel.hidden = text.length == 0;
}

- (void)_setBusy:(BOOL)busy {
  self.busy = busy;
  [self.titleField setEnabled:!busy];
  [self.urlFused setFieldEnabled:!busy];
  [self.urlFused setActionEnabled:!busy];
  [self.urlFused setActionTitle:(busy && !self.outcome) ? @"探测中" : @"探测"];
  self.modeSeg.enabled = !busy;
  [self.enrollFused setFieldEnabled:!busy];
  [self.claimFused setFieldEnabled:!busy];
  [self.importPassFused setFieldEnabled:!busy];
  [self.pickBar setBarEnabled:!busy];
  self.readyBtn.enabled = !busy;
  [self _refreshJoinActions];
}

- (void)_refreshJoinActions {
  BOOL canEnroll = [self _canEnroll];
  BOOL canClaim = [self _canClaim];
  BOOL canImport = [self _canImport];
  [self.enrollFused setActionEnabled:!self.busy && canEnroll];
  self.enrollBlockedHint.hidden = canEnroll;
  [self.claimFused setActionEnabled:!self.busy && canClaim];
  [self.importPassFused setActionEnabled:!self.busy && canImport];
}

- (void)_refreshSections {
  BOOL hasOutcome = self.outcome != nil;
  self.probeSection.hidden = !hasOutcome;
  self.joinSection.hidden = ![self _showJoin];

  if (hasOutcome) {
    UIColor *accent = [self _accentForKind:self.outcome.kind];
    self.probeCard.backgroundColor = [accent colorWithAlphaComponent:0.08];
    [AutumnOpsUITheme applyBorderToLayer:self.probeCard.layer color:[accent colorWithAlphaComponent:0.35] width:1];
    self.probeAccentBar.backgroundColor = accent;
    self.probeMessageLabel.text = self.outcome.message ?: @"";
    self.probeNextLabel.text = self.outcome.nextStep ?: @"";
    self.probeNextLabel.hidden = self.outcome.nextStep.length == 0;
    if (self.resolvedBase.length) {
      self.probeBaseLabel.text = [NSString stringWithFormat:@"可用地址：%@", self.resolvedBase];
      self.probeBaseLabel.hidden = NO;
    } else {
      self.probeBaseLabel.text = @"";
      self.probeBaseLabel.hidden = YES;
    }
    BOOL needReset = self.outcome.kind == AutumnOpsProbeKindNeedReset;
    BOOL ready = self.outcome.kind == AutumnOpsProbeKindReady;
    self.recoveryBtn.hidden = !needReset;
    self.readyBtn.hidden = !ready;
  }

  [self _refreshJoinActions];
}

- (void)_modeChanged {
  self.mode = (AutumnOpsAddMode)self.modeSeg.selectedSegmentIndex;
  self.enrollBody.hidden = self.mode != AutumnOpsAddModeEnroll;
  self.claimBody.hidden = self.mode != AutumnOpsAddModeClaim;
  self.importBody.hidden = self.mode != AutumnOpsAddModeImport;
}

- (void)_urlChanged {
  if (self.resolvedBase || self.outcome) {
    self.resolvedBase = nil;
    self.outcome = nil;
    [self _refreshSections];
  }
}

- (void)_dismissKeyboard {
  [self.view endEditing:YES];
}

#pragma mark - UIGestureRecognizerDelegate / UITextFieldDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
  UIView *v = touch.view;
  while (v && v != self.scroll) {
    if ([v isKindOfClass:[UITextField class]] || [v isKindOfClass:[UITextView class]]) {
      return NO;
    }
    v = v.superview;
  }
  return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
  return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if (textField == self.titleField) {
    [self.urlFused.textField becomeFirstResponder];
    return YES;
  }
  if (textField == self.urlFused.textField) {
    [textField resignFirstResponder];
    [self _probe];
    return YES;
  }
  [textField resignFirstResponder];
  if (textField == self.enrollFused.textField) {
    [self _enrollAndOpen];
  } else if (textField == self.claimFused.textField) {
    [self _claimAndOpen];
  } else if (textField == self.importPassFused.textField) {
    [self _importCredentialAndOpen];
  }
  return YES;
}

- (NSString *)_effectiveBaseUrl {
  if (self.resolvedBase.length) return self.resolvedBase;
  return [AutumnOpsEndpoint resolve:self.urlFused.textField.text].candidates.firstObject ?: @"";
}

#pragma mark - Actions

- (void)_pasteTapped:(UIButton *)sender {
  if (self.busy) return;
  UITextField *field = objc_getAssociatedObject(sender, kAutumnOpsPasteFieldKey);
  if (![field isKindOfClass:[UITextField class]]) return;
  NSString *clip = UIPasteboard.generalPasteboard.string ?: @"";
  if (!clip.length) {
    [self _setStatus:@"剪贴板为空"];
    return;
  }
  field.text = clip;
  [self _setStatus:@"已从剪贴板粘贴"];
}

- (void)_probe {
  if (self.busy) return;
  AutumnOpsValidateResult *titleOk = [AutumnOpsValidators siteTitle:self.titleField.text];
  if (!titleOk.ok) {
    [self _setStatus:titleOk.error];
    return;
  }
  AutumnOpsValidateResult *ep = [AutumnOpsValidators siteEndpoint:self.urlFused.textField.text];
  if (!ep.ok) {
    [self _setStatus:ep.error];
    return;
  }
  AutumnOpsEndpointPlan *plan = [AutumnOpsEndpoint resolve:self.urlFused.textField.text];
  if (plan.isEmpty) {
    [self _setStatus:@"请填写域名或 IP"];
    return;
  }
  AutumnOpsSiteEntry *tmp = [AutumnOpsSiteEntry new];
  tmp.id = @"tmp";
  tmp.baseUrl = plan.candidates.firstObject ?: self.urlFused.textField.text;
  AutumnOpsStore *store = [self.siteStore credentialStoreForSite:tmp];
  BOOL hasCert = [store load:nil] != nil;

  self.outcome = nil;
  [self _refreshSections];
  [self _setBusy:YES];
  [self _setStatus:@"探测中…"];

  __weak typeof(self) weakSelf = self;
  [AutumnOpsEndpoint probePlan:plan store:store hasLocalCert:hasCert completion:^(AutumnOpsResolvedProbe *resolved) {
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) return;
    [self _setBusy:NO];
    self.outcome = resolved.outcome;
    self.resolvedBase = resolved.baseUrl.length ? resolved.baseUrl : tmp.baseUrl;
    if (self.resolvedBase.length && resolved.outcome.kind != AutumnOpsProbeKindNetwork) {
      self.urlFused.textField.text = self.resolvedBase;
    }
    NSMutableString *st = [NSMutableString stringWithString:resolved.outcome.message ?: @""];
    if (resolved.outcome.nextStep.length) [st appendFormat:@"\n%@", resolved.outcome.nextStep];
    if (resolved.tried.count > 1) [st appendFormat:@"\n尝试：%@", [resolved.tried componentsJoinedByString:@" → "]];
    [self _setStatus:st];

    if (resolved.outcome.kind == AutumnOpsProbeKindNeedReset) {
      self.modeSeg.selectedSegmentIndex = AutumnOpsAddModeImport;
      [self _modeChanged];
    } else if (resolved.outcome.kind == AutumnOpsProbeKindPending) {
      self.modeSeg.selectedSegmentIndex = AutumnOpsAddModeEnroll;
      [self _modeChanged];
    }
    [self _refreshSections];
  }];
}

- (void)_recovery {
  AutumnOpsRecoveryViewController *vc =
      [[AutumnOpsRecoveryViewController alloc] initWithSiteTitle:self.titleField.text
                                                         baseUrl:[self _effectiveBaseUrl]];
  [self.navigationController pushViewController:vc animated:YES];
}

- (void)_replaceWithManage:(AutumnOpsSiteEntry *)entry {
  UINavigationController *nav = self.navigationController;
  if (!nav) return;
  AutumnOpsManageViewController *m =
      [[AutumnOpsManageViewController alloc] initWithSiteEntry:entry siteStore:self.siteStore];
  NSMutableArray *stack = [nav.viewControllers mutableCopy];
  if (stack.count) [stack removeLastObject];
  [stack addObject:m];
  [nav setViewControllers:stack animated:YES];
}

- (void)_saveReadyAndOpen {
  if (self.busy) return;
  NSString *base = [self _effectiveBaseUrl];
  if (!base.length) {
    [self _setStatus:@"请先成功探测"];
    return;
  }
  AutumnOpsSiteEntry *existing = [self.siteStore findByBaseUrl:base];
  AutumnOpsSiteEntry *e = existing ?: [AutumnOpsSiteEntry new];
  if (!existing) {
    e.id = [NSUUID UUID].UUIDString;
    e.title = self.titleField.text.length ? self.titleField.text : base;
    e.baseUrl = base;
  }
  e.siteId = self.outcome.result.siteId ?: e.siteId;
  e.serverFingerprint = self.outcome.result.serverFingerprint ?: e.serverFingerprint;
  e.enrolled = YES;
  AutumnOpsCredentialBundle *bundle = [[self.siteStore credentialStoreForSite:e] load:nil];
  if (bundle.certId.length) e.certId = bundle.certId;
  [self.siteStore upsertSite:e error:nil];
  [self _replaceWithManage:e];
}

- (void)_enrollAndOpen {
  if (self.busy) return;
  NSString *base = [self _effectiveBaseUrl];
  AutumnOpsValidateResult *ep = [AutumnOpsValidators siteEndpoint:self.urlFused.textField.text];
  if (!ep.ok || !base.length) {
    [self _setStatus:ep.error ?: @"请先填写有效地址并探测"];
    return;
  }
  AutumnOpsValidateResult *sec = [AutumnOpsValidators enrollSecret:self.enrollFused.textField.text];
  if (!sec.ok) {
    [self _setStatus:sec.error];
    return;
  }
  if (self.outcome.kind != AutumnOpsProbeKindPending) {
    [self _setStatus:@"请先探测，且站点需处于可首次入驻状态"];
    return;
  }
  [self _setBusy:YES];
  [self _setStatus:@"入驻中…"];
  [self _enrollOrClaimBase:base mode:AutumnOpsAddModeEnroll secret:self.enrollFused.textField.text];
}

- (void)_claimAndOpen {
  if (self.busy) return;
  NSString *base = [self _effectiveBaseUrl];
  AutumnOpsValidateResult *ep = [AutumnOpsValidators siteEndpoint:self.urlFused.textField.text];
  if (!ep.ok || !base.length) {
    [self _setStatus:ep.error ?: @"请先填写有效地址并探测"];
    return;
  }
  if (![self _canClaim]) {
    [self _setStatus:@"当前探测结果不允许认领"];
    return;
  }
  AutumnOpsValidateResult *sec = [AutumnOpsValidators claimSecret:self.claimFused.textField.text];
  if (!sec.ok) {
    [self _setStatus:sec.error];
    return;
  }
  [self _setBusy:YES];
  [self _setStatus:@"认领入驻中…"];
  [self _enrollOrClaimBase:base mode:AutumnOpsAddModeClaim secret:self.claimFused.textField.text];
}

- (void)_enrollOrClaimBase:(NSString *)base mode:(AutumnOpsAddMode)mode secret:(NSString *)secret {
  AutumnOpsSiteEntry *existing = [self.siteStore findByBaseUrl:base];
  AutumnOpsSiteEntry *e = existing ?: [AutumnOpsSiteEntry new];
  if (!existing) {
    e.id = [NSUUID UUID].UUIDString;
    e.title = self.titleField.text.length ? self.titleField.text : base;
    e.baseUrl = base;
  }
  AutumnOpsStore *store = [self.siteStore credentialStoreForSite:e];
  AutumnOpsClient *client = [[AutumnOpsClient alloc] initWithBaseUrl:base store:store];
  client.deviceLabel = AutumnOpsUIConfig.deviceLabel;
  __weak typeof(self) weakSelf = self;
  void (^done)(AutumnOpsEnrollResult *, NSError *) = ^(AutumnOpsEnrollResult *result, NSError *error) {
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) return;
    [self _setBusy:NO];
    if (error) {
      [self _setStatus:error.localizedDescription];
      return;
    }
    e.siteId = result.siteId;
    e.certId = result.certId;
    e.serverFingerprint = result.serverFingerprint;
    e.enrolled = YES;
    [self.siteStore upsertSite:e error:nil];
    [self _replaceWithManage:e];
  };
  if (mode == AutumnOpsAddModeEnroll) {
    [client enrollWithSecret:secret completion:done];
  } else {
    [client claimWithSecret:secret completion:done];
  }
}

- (void)_pickCredentialFile {
  if (self.busy) return;
  UTType *t = [UTType typeWithFilenameExtension:@"autumnops"] ?: UTTypeJSON;
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[ t, UTTypeJSON ]];
  picker.delegate = self;
  [self presentViewController:picker animated:YES completion:nil];
}

- (void)_importCredentialAndOpen {
  if (self.busy) return;
  if (![self _canImport]) {
    [self _setStatus:@"探测失败，无法导入凭证"];
    return;
  }
  if (!self.pickedCredential) {
    [self _setStatus:@"请先选择运维凭证文件"];
    return;
  }
  AutumnOpsValidateResult *vr = [AutumnOpsValidators sharePassphrase:self.importPassFused.textField.text];
  if (!vr.ok) {
    [self _setStatus:vr.error];
    return;
  }
  NSString *pass = [self.importPassFused.textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *base = self.resolvedBase.length ? self.resolvedBase : (self.pickedCredential.baseUrl ?: self.urlFused.textField.text);
  base = [AutumnOpsSiteEntry normalizeBaseUrl:base];
  if (!base.length) {
    [self _setStatus:@"请先填写有效地址并探测"];
    return;
  }

  AutumnOpsSiteEntry *existing = [self.siteStore findByBaseUrl:base];
  AutumnOpsSiteEntry *e = existing ?: [AutumnOpsSiteEntry new];
  if (!existing) {
    e.id = [NSUUID UUID].UUIDString;
    e.title = self.titleField.text.length ? self.titleField.text : base;
    e.baseUrl = base;
  }
  AutumnOpsStore *store = [self.siteStore credentialStoreForSite:e];
  AutumnOpsClient *client = [[AutumnOpsClient alloc] initWithBaseUrl:base store:store];
  client.deviceLabel = AutumnOpsUIConfig.deviceLabel;

  [self _setBusy:YES];
  [self _setStatus:@"导入中…"];
  NSError *err = nil;
  if (![client importWrapped:self.pickedCredential.wrapped passphrase:pass error:&err]) {
    [self _setBusy:NO];
    self.pickedCredential = nil;
    self.pickedCredentialName = nil;
    [self.pickBar setLabelText:@"尚未选择运维凭证" selected:NO];
    [self.pickBar setActionTitle:@"选文件"];
    self.pickedBaseLabel.hidden = YES;
    [self _setStatus:err.localizedDescription ?: @"导入失败"];
    return;
  }

  NSString *fileFp = self.pickedCredential.serverFingerprint;
  __weak typeof(self) weakSelf = self;
  [AutumnOpsEndpoint probePlan:[AutumnOpsEndpoint resolve:base]
                         store:store
                  hasLocalCert:YES
                    completion:^(AutumnOpsResolvedProbe *resolved) {
                      __strong typeof(weakSelf) self = weakSelf;
                      if (!self) return;
                      [self _setBusy:NO];
                      NSString *probeFp = resolved.outcome.result.serverFingerprint;
                      if (probeFp.length && fileFp.length && ![probeFp isEqualToString:fileFp]) {
                        [store clear:nil];
                        self.pickedCredential = nil;
                        self.pickedCredentialName = nil;
                        [self.pickBar setLabelText:@"尚未选择运维凭证" selected:NO];
                        [self.pickBar setActionTitle:@"选文件"];
                        self.pickedBaseLabel.hidden = YES;
                        [self _setStatus:@"凭证与站点指纹不一致，已取消"];
                        return;
                      }
                      AutumnOpsCredentialBundle *b = [client currentBundle:nil];
                      e.siteId = b.siteId ?: self.pickedCredential.siteId;
                      e.certId = b.certId ?: self.pickedCredential.certId;
                      e.serverFingerprint = fileFp ?: b.serverFingerprint;
                      e.enrolled = YES;
                      e.baseUrl = resolved.baseUrl.length ? resolved.baseUrl : base;
                      [self.siteStore upsertSite:e error:nil];
                      [self _replaceWithManage:e];
                    }];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  NSURL *url = urls.firstObject;
  [url startAccessingSecurityScopedResource];
  NSData *data = [NSData dataWithContentsOfURL:url];
  [url stopAccessingSecurityScopedResource];
  NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  AutumnOpsParseResult *parsed = [AutumnOpsParseResult parse:raw ?: @""];
  if (!parsed.ok) {
    [self _setStatus:parsed.error ?: @"凭证文件无效"];
    return;
  }
  self.pickedCredential = parsed.payload;
  self.pickedCredentialName = url.lastPathComponent;
  [self.pickBar setLabelText:[NSString stringWithFormat:@"已选：%@", self.pickedCredentialName] selected:YES];
  [self.pickBar setActionTitle:@"重选"];
  if (parsed.payload.baseUrl.length) {
    self.pickedBaseLabel.text = [NSString stringWithFormat:@"文件内站点：%@", parsed.payload.baseUrl];
    self.pickedBaseLabel.hidden = NO;
  } else {
    self.pickedBaseLabel.hidden = YES;
  }
  [self _setStatus:@""];
}

@end
