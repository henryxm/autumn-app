#import "AutumnOpsManageViewController.h"
#import "AutumnOpsRecoveryViewController.h"
#import "AutumnOpsShieldPanelView.h"
#import "AutumnOpsJumpPanelView.h"
#import "AutumnOpsRuntimePanelView.h"
#import "AutumnOpsIpListPanelView.h"
#import "AutumnOpsCertPanelView.h"
#import "AutumnOpsConfirmPresenter.h"
#import "AutumnOpsFusedFieldActionView.h"
#import "AutumnOpsSecureTokenFormController.h"
#import "AutumnOpsUITheme.h"
#import "AutumnOpsScrollableTabBar.h"
#import "AutumnOpsPageChromeView.h"
#import "AutumnOpsSectionCardView.h"
#import "AutumnOpsSitesViewController.h"
#import "AutumnOpsUIConfig.h"
#import "AutumnOpsUIControls.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>

typedef NS_ENUM(NSInteger, AutumnOpsClearTokenUI) {
  AutumnOpsClearTokenUIEmpty = 0,
  AutumnOpsClearTokenUIPending,
  AutumnOpsClearTokenUISaved,
  AutumnOpsClearTokenUIReady,
  AutumnOpsClearTokenUIServerUnset,
  AutumnOpsClearTokenUIError,
};

@interface AutumnOpsManageViewController ()
@property (nonatomic, strong) AutumnOpsClient *client;
@property (nonatomic, strong) AutumnOpsSiteEntry *siteEntry;
@property (nonatomic, strong) AutumnOpsSiteStore *siteStore;
@property (nonatomic, strong, nullable) AutumnOpsPageChromeView *pageChrome;
@property (nonatomic, strong) AutumnOpsScrollableTabBar *tabs;
@property (nonatomic, strong) UIView *statusBar;
@property (nonatomic, strong) UIView *contentHost;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIBarButtonItem *sitesBarItem;
@property (nonatomic, strong) UIButton *chromeSitesBtn;

@property (nonatomic, strong) UIView *overviewPanel;
@property (nonatomic, strong) UIScrollView *overviewScroll;
@property (nonatomic, strong) UIStackView *overviewStack;
@property (nonatomic, strong) AutumnOpsRuntimePanelView *runtimePanel;
@property (nonatomic, strong) AutumnOpsIpListPanelView *adminIpPanel;
@property (nonatomic, strong) AutumnOpsIpListPanelView *whitePanel;
@property (nonatomic, strong) AutumnOpsIpListPanelView *blackPanel;
@property (nonatomic, strong) AutumnOpsCertPanelView *certPanel;
@property (nonatomic, strong) AutumnOpsFusedFieldActionView *firewallFused;

@property (nonatomic, strong) AutumnOpsSectionCardView *siteInfoCard;
@property (nonatomic, strong) AutumnOpsSectionCardView *discoverCard;
@property (nonatomic, strong) AutumnOpsSectionCardView *gateCard;
@property (nonatomic, strong) AutumnOpsSectionCardView *tokenCard;
@property (nonatomic, strong) AutumnOpsSectionCardView *shareCard;
@property (nonatomic, strong) AutumnOpsChipView *discoverChip;
@property (nonatomic, strong) AutumnOpsChipView *gateChip;
@property (nonatomic, strong) UIButton *discoverActionBtn;
@property (nonatomic, strong) UIButton *gateActionBtn;
@property (nonatomic, strong) UIButton *claimBtn;
@property (nonatomic, strong) UITextView *shareUrlView;
@property (nonatomic, strong) AutumnOpsChipView *clearTokenStatusChip;
@property (nonatomic, strong) UIButton *clearTokenActionBtn;
@property (nonatomic, strong) UIButton *clearTokenClearBtn;
@property (nonatomic) NSInteger activeCount;

@property (nonatomic, strong) UITextField *clearTokenField;
@property (nonatomic, strong) UILabel *clearTokenHint;
@property (nonatomic, copy, nullable) NSString *clearTokenError;

@property (nonatomic, copy) NSArray<NSDictionary *> *certs;
@property (nonatomic) NSInteger firewallCount;

@property (nonatomic, copy) NSString *currentIp;
@property (nonatomic) BOOL currentIpInAdmin;
@property (nonatomic) BOOL currentIpInWhite;
@property (nonatomic, strong) AutumnOpsShieldPanelView *shieldPanel;
@property (nonatomic, strong) AutumnOpsJumpPanelView *jumpPanel;
@property (nonatomic, strong, nullable) NSNumber *adminIpEnable;
@property (nonatomic, strong, nullable) NSNumber *discoverEnabled;
@property (nonatomic, strong, nullable) NSNumber *clearTokenConfigured;
@property (nonatomic) AutumnOpsClearTokenUI clearTokenStatus;
@property (nonatomic, copy, nullable) NSString *verifiedClearToken;
@property (nonatomic) NSInteger busyDepth;
@end

@implementation AutumnOpsManageViewController

- (instancetype)initWithClient:(AutumnOpsClient *)client {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _client = client;
    _certs = @[];
  }
  return self;
}

- (instancetype)initWithSiteEntry:(AutumnOpsSiteEntry *)entry siteStore:(AutumnOpsSiteStore *)siteStore {
  AutumnOpsStore *store = [siteStore credentialStoreForSite:entry];
  AutumnOpsClient *client = [[AutumnOpsClient alloc] initWithBaseUrl:entry.baseUrl store:store];
  client.deviceLabel = AutumnOpsUIConfig.deviceLabel;
  self = [self initWithClient:client];
  if (self) {
    _siteEntry = entry;
    _siteStore = siteStore;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  NSString *title = self.siteEntry.title.length ? self.siteEntry.title : @"站点管理";
  self.title = title;

  UIImage *sitesImg = [AutumnOpsUIControls sitesListIconWithSize:22];
  self.sitesBarItem = [[UIBarButtonItem alloc] initWithImage:sitesImg style:UIBarButtonItemStylePlain target:self action:@selector(_goSites)];
  self.sitesBarItem.accessibilityLabel = @"站点列表";
  self.navigationItem.rightBarButtonItems = @[self.sitesBarItem];

  _chromeSitesBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [_chromeSitesBtn setImage:sitesImg forState:UIControlStateNormal];
  _chromeSitesBtn.tintColor = UIColor.labelColor;
  _chromeSitesBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
  _chromeSitesBtn.accessibilityLabel = @"站点列表";
  [_chromeSitesBtn addTarget:self action:@selector(_goSites) forControlEvents:UIControlEventTouchUpInside];
  // 对齐 Flutter：微信小程序式圆环+中心点「回到站点列表」；刷新改为概览/证书下拉
  _pageChrome = [AutumnOpsPageChromeView installOnViewController:self title:title rightItems:@[_chromeSitesBtn]];
  UIView *topAnchorView = _pageChrome;
  if (!_pageChrome) {
    // 系统栏可见：保留 navigationItem
  }

  _tabs = [[AutumnOpsScrollableTabBar alloc] initWithItems:@[@"概览", @"运行", @"管理IP", @"白名单", @"黑名单", @"盾牌", @"跳转", @"证书"]];
  _tabs.selectedIndex = 0;
  [_tabs addTarget:self action:@selector(_tabChanged) forControlEvents:UIControlEventValueChanged];

  _statusBar = [UIView new];
  // 轻量系统次级底，随明暗适配；不用固定 M3 卡片灰
  _statusBar.backgroundColor = UIColor.secondarySystemBackgroundColor;
  _statusLabel = [UILabel new];
  _statusLabel.numberOfLines = 2;
  _statusLabel.font = [UIFont systemFontOfSize:13];
  _statusLabel.textColor = UIColor.labelColor;
  _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  [_statusBar addSubview:_statusLabel];
  [_statusBar addSubview:_spinner];

  _contentHost = [UIView new];
  [self.view addSubview:_tabs];
  [self.view addSubview:_statusBar];
  [self.view addSubview:_contentHost];

  [_tabs mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.equalTo(self.view);
    if (topAnchorView) make.top.equalTo(topAnchorView.mas_bottom);
    else make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
    make.height.mas_equalTo(46);
  }];
  [_statusBar mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.equalTo(self.view);
    make.top.equalTo(_tabs.mas_bottom);
  }];
  [_statusLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(_statusBar).offset(16);
    make.top.equalTo(_statusBar).offset(10);
    make.bottom.equalTo(_statusBar).offset(-10);
    make.right.equalTo(_spinner.mas_left).offset(-8);
  }];
  [_spinner mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(_statusLabel);
    make.right.equalTo(_statusBar).offset(-16);
    make.width.height.mas_equalTo(16);
  }];
  [_contentHost mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.bottom.equalTo(self.view);
    make.top.equalTo(_statusBar.mas_bottom);
  }];

  [self _buildPanels];
  [self _tabChanged];
  [self _refreshAll];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  if (self.pageChrome) {
    self.pageChrome.showsBack = [AutumnOpsPageChromeView canGoBackFromViewController:self];
  }
}

#pragma mark - Nav

- (void)_goSites {
  UINavigationController *nav = self.navigationController;
  if (!nav) return;
  for (UIViewController *vc in nav.viewControllers) {
    if ([vc isKindOfClass:[AutumnOpsSitesViewController class]]) {
      [nav popToViewController:vc animated:YES];
      return;
    }
  }
  NSMutableArray *stack = [NSMutableArray array];
  if (nav.viewControllers.firstObject) {
    [stack addObject:nav.viewControllers.firstObject];
  }
  [stack addObject:[AutumnOpsSitesViewController new]];
  [nav setViewControllers:stack animated:YES];
}

- (void)_updateChromeEnabled {
  BOOL enabled = self.busyDepth == 0;
  self.sitesBarItem.enabled = enabled;
  [AutumnOpsUIControls setControl:self.chromeSitesBtn enabled:enabled];
  [AutumnOpsUIControls setControl:self.discoverActionBtn enabled:enabled];
  [AutumnOpsUIControls setControl:self.gateActionBtn enabled:enabled];
  [AutumnOpsUIControls setControl:self.claimBtn enabled:enabled];
  if (!enabled) {
    [AutumnOpsUIControls setControl:self.clearTokenActionBtn enabled:NO];
  } else {
    [self _refreshClearTokenActionTitle];
  }
}

#pragma mark - Busy

- (void)_beginBusy {
  self.busyDepth++;
  [self.spinner startAnimating];
  [self _updateChromeEnabled];
}

- (void)_endBusy {
  self.busyDepth = MAX(0, self.busyDepth - 1);
  if (self.busyDepth == 0) [self.spinner stopAnimating];
  [self _updateChromeEnabled];
}

- (void)_setStatus:(NSString *)s {
  if (self.busyDepth > 0 && s.length) {
    self.statusLabel.text = [NSString stringWithFormat:@"处理中 · %@", s];
  } else {
    self.statusLabel.text = s;
  }
}

- (void)_toast:(NSString *)msg {
  if (!msg.length) return;
  UIView *box = [UIView new];
  box.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
  box.layer.cornerRadius = 10;
  box.clipsToBounds = YES;
  UILabel *l = [UILabel new];
  l.text = msg;
  l.textColor = UIColor.whiteColor;
  l.font = [UIFont systemFontOfSize:14];
  l.textAlignment = NSTextAlignmentCenter;
  l.numberOfLines = 0;
  [box addSubview:l];
  l.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [l.topAnchor constraintEqualToAnchor:box.topAnchor constant:10],
    [l.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-10],
    [l.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:16],
    [l.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-16],
  ]];
  UIView *host = self.view;
  [host addSubview:box];
  box.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [box.centerXAnchor constraintEqualToAnchor:host.centerXAnchor],
    [box.bottomAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.bottomAnchor constant:-24],
    [box.leadingAnchor constraintGreaterThanOrEqualToAnchor:host.leadingAnchor constant:32],
    [box.trailingAnchor constraintLessThanOrEqualToAnchor:host.trailingAnchor constant:-32],
  ]];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [UIView animateWithDuration:0.25 animations:^{ box.alpha = 0; } completion:^(BOOL finished) {
      [box removeFromSuperview];
    }];
  });
}

- (void)_confirm:(NSString *)title body:(NSString *)body ok:(void (^)(void))ok {
  [self _confirm:title body:body destructive:NO ok:ok];
}

- (void)_confirm:(NSString *)title body:(NSString *)body destructive:(BOOL)destructive ok:(void (^)(void))ok {
  [AutumnOpsConfirmPresenter presentFrom:self title:title body:body destructive:destructive onConfirm:ok];
}

#pragma mark - Panels

- (void)_buildPanels {
  // Overview — Flutter section cards
  _overviewPanel = [UIView new];
  _overviewScroll = [UIScrollView new];
  _overviewScroll.alwaysBounceVertical = YES;
  UIRefreshControl *overviewRC = [UIRefreshControl new];
  [overviewRC addTarget:self action:@selector(_pullRefreshAll) forControlEvents:UIControlEventValueChanged];
  _overviewScroll.refreshControl = overviewRC;
  _overviewStack = [[UIStackView alloc] init];
  _overviewStack.axis = UILayoutConstraintAxisVertical;
  _overviewStack.spacing = 12;
  [_overviewPanel addSubview:_overviewScroll];
  [_overviewScroll addSubview:_overviewStack];
  [_overviewScroll mas_makeConstraints:^(MASConstraintMaker *make) { make.edges.equalTo(_overviewPanel); }];
  [_overviewStack mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_overviewScroll).insets(UIEdgeInsetsMake(16, 16, 16, 16));
    make.width.equalTo(_overviewScroll).offset(-32);
  }];

  _siteInfoCard = [[AutumnOpsSectionCardView alloc] initWithTitle:@"站点信息" body:@"核对地址与证书指纹，确认连到正确的 Autumn 实例。"];
  [_overviewStack addArrangedSubview:_siteInfoCard];

  _discoverCard = [[AutumnOpsSectionCardView alloc] initWithTitle:@"站点发现页" body:@""];
  _discoverChip = [AutumnOpsUIControls chipWithText:@"发现已开" kind:AutumnOpsChipKindOn];
  _discoverActionBtn = [AutumnOpsUIControls buttonWithTitle:@"关闭" style:AutumnOpsButtonStyleOutlined target:self action:@selector(_discoverActionTapped)];
  UIView *discSpacer = [UIView new];
  [discSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  UIStackView *discRow = [[UIStackView alloc] initWithArrangedSubviews:@[_discoverChip, discSpacer, _discoverActionBtn]];
  discRow.axis = UILayoutConstraintAxisHorizontal;
  discRow.alignment = UIStackViewAlignmentCenter;
  discRow.spacing = 8;
  [_discoverCard.contentStack addArrangedSubview:discRow];
  [_overviewStack addArrangedSubview:_discoverCard];

  _gateCard = [[AutumnOpsSectionCardView alloc] initWithTitle:@"管理 IP 校验（门禁）" body:@""];
  _gateChip = [AutumnOpsUIControls chipWithText:@"已开" kind:AutumnOpsChipKindOn];
  _gateActionBtn = [AutumnOpsUIControls buttonWithTitle:@"关闭" style:AutumnOpsButtonStyleOutlined target:self action:@selector(_gateActionTapped)];
  UIView *gateSpacer = [UIView new];
  [gateSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  UIStackView *gateRow = [[UIStackView alloc] initWithArrangedSubviews:@[_gateChip, gateSpacer, _gateActionBtn]];
  gateRow.axis = UILayoutConstraintAxisHorizontal;
  gateRow.alignment = UIStackViewAlignmentCenter;
  gateRow.spacing = 8;
  [_gateCard.contentStack addArrangedSubview:gateRow];
  [_overviewStack addArrangedSubview:_gateCard];

  _tokenCard = [[AutumnOpsSectionCardView alloc] initWithTitle:@"清除确认令牌" body:@"用于关闭管理 IP 校验、删除「当前访问 IP」等危险操作的二次确认。"];
  [_tokenCard setOutlined:YES];
  UIImageView *shield = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shield"]];
  shield.tintColor = AutumnOpsUITheme.primary;
  shield.contentMode = UIViewContentModeScaleAspectFit;
  [_tokenCard setTitleLeading:shield];
  _clearTokenStatusChip = [AutumnOpsUIControls chipWithText:@"未填写" kind:AutumnOpsChipKindEmpty compact:YES];
  [_tokenCard setTitleAccessory:_clearTokenStatusChip];
  _clearTokenHint = [UILabel new];
  _clearTokenHint.numberOfLines = 0;
  _clearTokenHint.font = [UIFont systemFontOfSize:12];
  _clearTokenHint.textColor = AutumnOpsUITheme.onSurfaceVariant;
  _clearTokenHint.hidden = YES;
  UITextField *tokField = nil;
  UIButton *tokClear = nil;
  UIButton *tokAction = nil;
  UIView *tokBar = [AutumnOpsUIControls tokenInputBarWithField:&tokField
                                                   clearButton:&tokClear
                                                  actionButton:&tokAction
                                                        target:self
                                                        action:@selector(_saveClearToken)];
  _clearTokenField = tokField;
  _clearTokenClearBtn = tokClear;
  _clearTokenActionBtn = tokAction;
  [_clearTokenClearBtn addTarget:self action:@selector(_resetClearToken) forControlEvents:UIControlEventTouchUpInside];
  [_clearTokenField addTarget:self action:@selector(_clearTokenEdited) forControlEvents:UIControlEventEditingChanged];
  UITapGestureRecognizer *chipTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_showClearTokenError)];
  [_clearTokenStatusChip addGestureRecognizer:chipTap];
  _clearTokenStatusChip.userInteractionEnabled = YES;
  // Flutter：说明 →（错误提示）→ 输入条；间距 8 / 12
  _tokenCard.contentStack.spacing = 12;
  [_tokenCard.contentStack addArrangedSubview:_clearTokenHint];
  [_tokenCard.contentStack addArrangedSubview:tokBar];
  [_overviewStack addArrangedSubview:_tokenCard];

  _claimBtn = [AutumnOpsUIControls buttonWithTitle:@"认领当前 IP 为管理 IP" style:AutumnOpsButtonStyleFilled target:self action:@selector(_claimCurrentAdminIp)];
  UIImage *loc = [UIImage systemImageNamed:@"location.fill"];
  [_claimBtn setImage:loc forState:UIControlStateNormal];
  _claimBtn.tintColor = AutumnOpsUITheme.onPrimary;
  _claimBtn.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
  [_overviewStack addArrangedSubview:_claimBtn];

  _shareCard = [[AutumnOpsSectionCardView alloc] initWithTitle:@"分享管理入口" body:@""];
  _shareUrlView = [UITextView new];
  _shareUrlView.editable = NO;
  _shareUrlView.scrollEnabled = NO;
  _shareUrlView.backgroundColor = UIColor.clearColor;
  _shareUrlView.textContainerInset = UIEdgeInsetsZero;
  _shareUrlView.textContainer.lineFragmentPadding = 0;
  _shareUrlView.font = [UIFont systemFontOfSize:13];
  _shareUrlView.textColor = AutumnOpsUITheme.onSurface;
  _shareUrlView.dataDetectorTypes = UIDataDetectorTypeNone;
  [_shareCard.contentStack addArrangedSubview:_shareUrlView];
  UIButton *copyBtn = [AutumnOpsUIControls buttonWithTitle:@"复制链接" style:AutumnOpsButtonStyleOutlined target:self action:@selector(_copyDiscover)];
  UIButton *shareBtn = [AutumnOpsUIControls buttonWithTitle:@"分享" style:AutumnOpsButtonStyleTonal target:self action:@selector(_shareDiscover)];
  UIImageSymbolConfiguration *icfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
  [copyBtn setImage:[UIImage systemImageNamed:@"doc.on.doc" withConfiguration:icfg] forState:UIControlStateNormal];
  [shareBtn setImage:[UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:icfg] forState:UIControlStateNormal];
  copyBtn.tintColor = AutumnOpsUITheme.primary;
  shareBtn.tintColor = AutumnOpsUITheme.onSecondaryContainer;
  copyBtn.imageEdgeInsets = UIEdgeInsetsMake(0, -2, 0, 4);
  shareBtn.imageEdgeInsets = UIEdgeInsetsMake(0, -2, 0, 4);
  UIStackView *shareRow = [[UIStackView alloc] initWithArrangedSubviews:@[copyBtn, shareBtn]];
  shareRow.axis = UILayoutConstraintAxisHorizontal;
  shareRow.spacing = 8;
  shareRow.distribution = UIStackViewDistributionFillEqually;
  // Flutter SizedBox(8)；视觉上略增，避免链接与按钮贴紧
  [_shareCard.contentStack setCustomSpacing:16 afterView:_shareUrlView];
  [_shareCard.contentStack addArrangedSubview:shareRow];
  [_overviewStack addArrangedSubview:_shareCard];

  UIButton *recovery = [AutumnOpsUIControls buttonWithTitle:@"丢钥 / 无法入驻时如何恢复" style:AutumnOpsButtonStyleOutlined target:self action:@selector(_openRecovery)];
  UIImageSymbolConfiguration *helpCfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
  [recovery setImage:[UIImage systemImageNamed:@"questionmark.circle" withConfiguration:helpCfg] forState:UIControlStateNormal];
  recovery.tintColor = AutumnOpsUITheme.primary;
  recovery.imageEdgeInsets = UIEdgeInsetsMake(0, -2, 0, 4);
  [_overviewStack addArrangedSubview:recovery];
  [_overviewStack setCustomSpacing:8 afterView:_shareCard];

  [self _reloadOverviewCards];

  __weak typeof(self) weakSelf = self;
  _adminIpPanel = [self _makeAdminIpPanel];
  _whitePanel = [self _makeWhiteIpPanel];
  _blackPanel = [self _makeBlackIpPanel];

  _runtimePanel = [[AutumnOpsRuntimePanelView alloc] initWithClient:self.client toast:^(NSString *msg) {
    [weakSelf _toast:msg];
  } setBusy:^(BOOL busy) {
    if (busy) [weakSelf _beginBusy];
    else [weakSelf _endBusy];
  }];
  _shieldPanel = [[AutumnOpsShieldPanelView alloc] initWithClient:self.client toast:^(NSString *msg) {
    [weakSelf _toast:msg];
  } setBusy:^(BOOL busy) {
    if (busy) [weakSelf _beginBusy];
    else [weakSelf _endBusy];
  }];
  _jumpPanel = [[AutumnOpsJumpPanelView alloc] initWithClient:self.client toast:^(NSString *msg) {
    [weakSelf _toast:msg];
  } setBusy:^(BOOL busy) {
    if (busy) [weakSelf _beginBusy];
    else [weakSelf _endBusy];
  }];

  _certPanel = [[AutumnOpsCertPanelView alloc] initWithClient:self.client
                                                   siteEntry:self.siteEntry
                                                   siteStore:self.siteStore
                                                       toast:^(NSString *msg) { [weakSelf _toast:msg]; }
                                                     setBusy:^(BOOL busy) {
                                                       if (busy) [weakSelf _beginBusy];
                                                       else [weakSelf _endBusy];
                                                     }
                                               onNeedRefresh:^{ [weakSelf _refreshAll]; }
                                            onLastCertRevoked:^{
                                              [weakSelf _markSiteUnenrolledAndClear];
                                              AutumnOpsRecoveryViewController *vc =
                                                  [[AutumnOpsRecoveryViewController alloc] initWithSiteTitle:weakSelf.siteEntry.title
                                                                                                     baseUrl:weakSelf.client.baseUrl];
                                              NSMutableArray *stack = [(weakSelf.navigationController.viewControllers ?: @[]) mutableCopy];
                                              if (stack.count) [stack removeLastObject];
                                              [stack addObject:vc];
                                              [weakSelf.navigationController setViewControllers:stack animated:YES];
                                            }];
}

- (AutumnOpsIpClearTokenResolver)_ipClearTokenResolver {
  __weak typeof(self) weakSelf = self;
  return ^(NSString *reason, void (^done)(NSString *token)) {
    [weakSelf _resolveClearTokenWithReason:reason completion:done];
  };
}

- (void)_resolveClearTokenWithReason:(NSString *)reason completion:(void (^)(NSString *token))completion {
  if (self.clearTokenConfigured != nil && !self.clearTokenConfigured.boolValue) {
    [self _toast:@"请先在概览页配置清除确认令牌"];
    if (completion) completion(nil);
    return;
  }
  NSString *ready = [self _readyClearTokenOrNil];
  if (ready.length) {
    if (completion) completion(ready);
    return;
  }
  AutumnOpsSecureTokenFormController *vc =
      [[AutumnOpsSecureTokenFormController alloc] initWithTitle:@"清除确认令牌"
                                                         reason:reason.length ? reason : @"请输入清除确认令牌"
                                                     fieldLabel:@"请输入清除确认令牌"
                                                    fieldHelper:@"在系统加固 / 安全配置中查看"
                                                   confirmLabel:@"校验并继续"
                                                    initialText:self.clearTokenField.text];
  __weak typeof(self) weakSelf = self;
  vc.onResult = ^(NSString *tok) {
    if (!tok.length) {
      if (completion) completion(nil);
      return;
    }
    AutumnOpsValidateResult *check = [AutumnOpsValidators clearToken:tok];
    if (!check.ok) {
      [weakSelf _toast:check.error ?: @"令牌无效"];
      if (completion) completion(nil);
      return;
    }
    [weakSelf _beginBusy];
    [weakSelf.client gateVerifyClearToken:tok completion:^(NSDictionary *data, NSError *error) {
      [weakSelf _endBusy];
      if (error) {
        [weakSelf _toast:error.localizedDescription];
        if (completion) completion(nil);
        return;
      }
      weakSelf.clearTokenField.text = tok;
      weakSelf.verifiedClearToken = tok;
      weakSelf.clearTokenStatus = AutumnOpsClearTokenUIReady;
      [weakSelf _reloadOverviewCards];
      if (completion) completion(tok);
    }];
  };
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
  nav.modalPresentationStyle = UIModalPresentationFormSheet;
  [self presentViewController:nav animated:YES completion:nil];
}

- (void)_syncIpPanelsMembership {
  self.adminIpPanel.currentIp = self.currentIp ?: @"";
  self.adminIpPanel.claimCurrentHidden = self.currentIpInAdmin;
  self.whitePanel.currentIp = self.currentIp ?: @"";
  self.whitePanel.claimCurrentHidden = self.currentIpInAdmin || self.currentIpInWhite;
  self.blackPanel.currentIp = self.currentIp ?: @"";
}

/// 管理/白名单 list：`forbidden` 0=启用 1=禁用；全部不传。
- (NSNumber *)_forbiddenParam:(AutumnOpsIpActiveFilter)filter {
  switch (filter) {
    case AutumnOpsIpActiveFilterActive: return @0;
    case AutumnOpsIpActiveFilterInactive: return @1;
    case AutumnOpsIpActiveFilterAll:
    default: return nil;
  }
}

/// 黑名单 list：`available` 0=生效 1=停用；全部不传。
- (NSNumber *)_availableParam:(AutumnOpsIpActiveFilter)filter {
  switch (filter) {
    case AutumnOpsIpActiveFilterActive: return @0;
    case AutumnOpsIpActiveFilterInactive: return @1;
    case AutumnOpsIpActiveFilterAll:
    default: return nil;
  }
}

- (AutumnOpsIpListPanelView *)_makeAdminIpPanel {
  __weak typeof(self) weakSelf = self;
  AutumnOpsIpPanelToast toast = ^(NSString *msg) { [weakSelf _toast:msg]; };
  AutumnOpsIpPanelBusy busy = ^(BOOL on) { if (on) [weakSelf _beginBusy]; else [weakSelf _endBusy]; };
  return [[AutumnOpsIpListPanelView alloc]
      initWithTitle:@"管理 IP"
        description:@"控制谁可以打开后台登录页（进门白名单）。与「用户白名单 / 黑名单」分表，互不影响。"
         statusMode:AutumnOpsIpStatusModeForbidden
        ipInputHint:@"请输入 IP 地址"
  allowClaimCurrent:YES
requireClearTokenForCurrent:YES
    rejectPolicyBlackIp:NO
             header:nil
           loadPage:^(NSInteger page, NSInteger limit, AutumnOpsIpActiveFilter filter, void (^done)(AutumnOpsIpPage *, NSError *)) {
             [weakSelf.client ensureSession:^(NSError *error) {
               if (error) { done(nil, error); return; }
               [weakSelf.client adminIpListPage:page limit:limit forbidden:[weakSelf _forbiddenParam:filter] completion:done];
             }];
           }
              onAdd:^(NSString *ip, BOOL claimCurrent, void (^done)(AutumnOpsIpUpsertResult *, NSError *)) {
                [weakSelf.client adminIpAdd:ip claimCurrent:claimCurrent completion:done];
              }
           onRemove:^(NSString *ip, NSString *clearToken, void (^done)(NSError *)) {
             [weakSelf.client adminIpRemove:ip clearToken:clearToken completion:^(NSDictionary *data, NSError *error) {
               done(error);
             }];
           }
           onToggle:^(NSString *ip, BOOL enable, void (^done)(NSError *)) {
             [weakSelf.client adminIpSetForbidden:ip forbidden:!enable completion:^(NSDictionary *data, NSError *error) {
               done(error);
             }];
           }
  resolveClearToken:[self _ipClearTokenResolver]
onMembershipMayChange:^{ [weakSelf _refreshAll]; }
              toast:toast
            setBusy:busy];
}

- (AutumnOpsIpListPanelView *)_makeWhiteIpPanel {
  __weak typeof(self) weakSelf = self;
  AutumnOpsIpPanelToast toast = ^(NSString *msg) { [weakSelf _toast:msg]; };
  AutumnOpsIpPanelBusy busy = ^(BOOL on) { if (on) [weakSelf _beginBusy]; else [weakSelf _endBusy]; };
  return [[AutumnOpsIpListPanelView alloc]
      initWithTitle:@"用户白名单"
        description:@"防火墙白名单：列入后可降低被误拉黑风险。与「管理 IP」不是同一张表。"
         statusMode:AutumnOpsIpStatusModeForbidden
        ipInputHint:@"请输入白名单 IP"
  allowClaimCurrent:YES
requireClearTokenForCurrent:YES
    rejectPolicyBlackIp:NO
             header:nil
           loadPage:^(NSInteger page, NSInteger limit, AutumnOpsIpActiveFilter filter, void (^done)(AutumnOpsIpPage *, NSError *)) {
             [weakSelf.client ensureSession:^(NSError *error) {
               if (error) { done(nil, error); return; }
               [weakSelf.client ipWhiteListPage:page limit:limit forbidden:[weakSelf _forbiddenParam:filter] completion:done];
             }];
           }
              onAdd:^(NSString *ip, BOOL claimCurrent, void (^done)(AutumnOpsIpUpsertResult *, NSError *)) {
                [weakSelf.client ipWhiteAdd:ip claimCurrent:claimCurrent completion:done];
              }
           onRemove:^(NSString *ip, NSString *clearToken, void (^done)(NSError *)) {
             [weakSelf.client ipWhiteRemove:ip clearToken:clearToken completion:^(NSDictionary *data, NSError *error) {
               done(error);
             }];
           }
           onToggle:^(NSString *ip, BOOL enable, void (^done)(NSError *)) {
             [weakSelf.client ipWhiteSetForbidden:ip forbidden:!enable completion:^(NSDictionary *data, NSError *error) {
               done(error);
             }];
           }
  resolveClearToken:[self _ipClearTokenResolver]
onMembershipMayChange:^{ [weakSelf _refreshAll]; }
              toast:toast
            setBusy:busy];
}

- (UIView *)_makeBlackFirewallHeader {
  UIStackView *box = [UIStackView new];
  box.axis = UILayoutConstraintAxisVertical;
  box.spacing = 8;
  UILabel *t = [UILabel new];
  t.text = @"自动拉黑阈值（策略 0.0.0.0）";
  t.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
  t.textColor = AutumnOpsUITheme.onSurface;
  UILabel *d = [UILabel new];
  d.text = @"同一刷新周期内访问超过该次数将自动加入黑名单。最小值 500。";
  d.numberOfLines = 0;
  d.font = [UIFont systemFontOfSize:12];
  d.textColor = AutumnOpsUITheme.onSurfaceVariant;
  _firewallFused = [[AutumnOpsFusedFieldActionView alloc] initWithHint:@"例如 1000"
                                                           actionTitle:@"保存"
                                                                target:self
                                                                action:@selector(_saveFirewallCount)];
  _firewallFused.textField.keyboardType = UIKeyboardTypeNumberPad;
  [box addArrangedSubview:t];
  [box addArrangedSubview:d];
  [box addArrangedSubview:_firewallFused];
  [self _loadFirewallCountIntoHeader];
  return box;
}

- (void)_loadFirewallCountIntoHeader {
  __weak typeof(self) weakSelf = self;
  [self.client ipBlackFirewallCount:^(NSInteger value, NSError *error) {
    if (error) return;
    weakSelf.firewallCount = value;
    weakSelf.firewallFused.textField.text = [NSString stringWithFormat:@"%ld", (long)value];
  }];
}

- (void)_saveFirewallCount {
  NSInteger n = self.firewallFused.textField.text.integerValue;
  if (n < 500) {
    [self _toast:@"阈值须为不小于 500 的整数"];
    return;
  }
  [self _beginBusy];
  __weak typeof(self) weakSelf = self;
  [self.client ipBlackSetFirewallCount:n completion:^(NSInteger value, NSError *error) {
    [weakSelf _endBusy];
    if (error) {
      [weakSelf _toast:error.localizedDescription];
      return;
    }
    weakSelf.firewallCount = value;
    weakSelf.firewallFused.textField.text = [NSString stringWithFormat:@"%ld", (long)value];
    [weakSelf _toast:[NSString stringWithFormat:@"已保存黑名单阈值：%ld 次/刷新周期", (long)value]];
  }];
}

- (AutumnOpsIpListPanelView *)_makeBlackIpPanel {
  __weak typeof(self) weakSelf = self;
  AutumnOpsIpPanelToast toast = ^(NSString *msg) { [weakSelf _toast:msg]; };
  AutumnOpsIpPanelBusy busy = ^(BOOL on) { if (on) [weakSelf _beginBusy]; else [weakSelf _endBusy]; };
  return [[AutumnOpsIpListPanelView alloc]
      initWithTitle:@"用户黑名单"
        description:@"防火墙黑名单：生效后直接拒绝访问。停用可保留记录而不再拦截。"
                     @"「0.0.0.0」不是普通 IP，而是服务端存放自动拉黑阈值的策略行（列表已隐藏）；请用上方阈值修改。"
         statusMode:AutumnOpsIpStatusModeAvailable
        ipInputHint:@"请输入黑名单 IP（勿填 0.0.0.0）"
  allowClaimCurrent:NO
requireClearTokenForCurrent:NO
    rejectPolicyBlackIp:YES
             header:[self _makeBlackFirewallHeader]
           loadPage:^(NSInteger page, NSInteger limit, AutumnOpsIpActiveFilter filter, void (^done)(AutumnOpsIpPage *, NSError *)) {
             [weakSelf.client ensureSession:^(NSError *error) {
               if (error) { done(nil, error); return; }
               [weakSelf.client ipBlackListPage:page limit:limit available:[weakSelf _availableParam:filter] completion:done];
             }];
           }
              onAdd:^(NSString *ip, BOOL claimCurrent, void (^done)(AutumnOpsIpUpsertResult *, NSError *)) {
                (void)claimCurrent;
                [weakSelf.client ipBlackAdd:ip completion:done];
              }
           onRemove:^(NSString *ip, NSString *clearToken, void (^done)(NSError *)) {
             (void)clearToken;
             [weakSelf.client ipBlackRemove:ip completion:^(NSDictionary *data, NSError *error) {
               done(error);
             }];
           }
           onToggle:^(NSString *ip, BOOL enable, void (^done)(NSError *)) {
             [weakSelf.client ipBlackSetAvailable:ip available:enable ? 0 : 1 completion:^(NSDictionary *data, NSError *error) {
               done(error);
             }];
           }
  resolveClearToken:nil
onMembershipMayChange:nil
              toast:toast
            setBusy:busy];
}

- (void)_tabChanged {
  for (UIView *v in self.contentHost.subviews) [v removeFromSuperview];
  NSArray *panels = @[self.overviewPanel, self.runtimePanel, self.adminIpPanel, self.whitePanel, self.blackPanel, self.shieldPanel, self.jumpPanel, self.certPanel];
  NSInteger i = self.tabs.selectedIndex;
  if (i < 0 || i >= (NSInteger)panels.count) return;
  UIView *p = panels[i];
  [self.contentHost addSubview:p];
  [p mas_makeConstraints:^(MASConstraintMaker *make) { make.edges.equalTo(self.contentHost); }];
  if (i == 1) [self.runtimePanel reload];
  if (i == 2) {
    [self _syncIpPanelsMembership];
    [self.adminIpPanel reload];
  }
  if (i == 3) {
    [self _syncIpPanelsMembership];
    [self.whitePanel reload];
  }
  if (i == 4) {
    [self _syncIpPanelsMembership];
    [self _loadFirewallCountIntoHeader];
    [self.blackPanel reload];
  }
  if (i == 5) [self.shieldPanel reload];
  if (i == 6) [self.jumpPanel reload];
  if (i == 7) [self.certPanel reload];
}

#pragma mark - Refresh

- (void)_pullRefreshAll {
  [self _refreshAll];
}

- (void)_endGlobalPullRefresh {
  if (self.overviewScroll.refreshControl.refreshing) {
    [self.overviewScroll.refreshControl endRefreshing];
  }
}

- (void)_refreshAll {
  [self _beginBusy];
  [self.client ensureSession:^(NSError *error) {
    if (error) {
      [self _endBusy];
      [self _endGlobalPullRefresh];
      [self _setStatus:error.localizedDescription];
      return;
    }
    [self.client gateGet:^(NSDictionary *data, NSError *err) {
      if (err) {
        [self _endBusy];
        [self _endGlobalPullRefresh];
        [self _setStatus:err.localizedDescription];
        return;
      }
      self.adminIpEnable = data[@"adminIpEnable"];
      id disc = data[@"discoverEnabled"];
      self.discoverEnabled = disc ? disc : @YES;
      self.clearTokenConfigured = data[@"clearTokenConfigured"];
      if (![self.clearTokenConfigured boolValue]) {
        self.clearTokenStatus = AutumnOpsClearTokenUIServerUnset;
        self.clearTokenHint.text = @"尚未配置：填写新令牌后点「保存」";
      } else if (self.clearTokenStatus == AutumnOpsClearTokenUIServerUnset) {
        self.clearTokenStatus = AutumnOpsClearTokenUIEmpty;
        self.clearTokenHint.text = @"";
      }
      [self _reloadOverviewCards];
      [self.client currentIp:^(NSDictionary *cur, NSError *e2) {
        self.currentIp = [NSString stringWithFormat:@"%@", cur[@"ip"] ?: @""];
        self.currentIpInAdmin = [cur[@"inAdmin"] boolValue];
        self.currentIpInWhite = [cur[@"inWhite"] boolValue];
        [self _loadCertsAfterMembership];
      }];
    }];
  }];
}

- (void)_loadCertsAfterMembership {
  [self.client certList:^(NSDictionary *data, NSError *err) {
    [self _endBusy];
    [self _endGlobalPullRefresh];
    if (err) {
      [self _setStatus:err.localizedDescription];
      return;
    }
    NSArray *list = [data[@"list"] isKindOfClass:[NSArray class]] ? data[@"list"] : @[];
    NSMutableArray *maps = [NSMutableArray array];
    for (id o in list) if ([o isKindOfClass:[NSDictionary class]]) [maps addObject:o];
    self.certs = maps;
    self.activeCount = [data[@"activeCount"] respondsToSelector:@selector(integerValue)] ? [data[@"activeCount"] integerValue] : maps.count;
    [self _setStatus:[NSString stringWithFormat:@"已同步 · 本机访问 IP：%@", self.currentIp.length ? self.currentIp : @"未知"]];
    [self _reloadOverviewCards];
    [self.certPanel applyCerts:self.certs activeCount:self.activeCount];
    [self _syncIpPanelsMembership];
    NSInteger tab = self.tabs.selectedIndex;
    if (tab == 1) [self.runtimePanel reload];
    if (tab == 2) [self.adminIpPanel reload];
    if (tab == 3) [self.whitePanel reload];
    if (tab == 4) {
      [self _loadFirewallCountIntoHeader];
      [self.blackPanel reload];
    }
    if (tab == 5) [self.shieldPanel reload];
    if (tab == 6) [self.jumpPanel reload];
  }];
}

#pragma mark - Overview actions

- (void)_reloadOverviewCards {
  BOOL gateOn = self.adminIpEnable.boolValue;
  BOOL discoverOn = self.discoverEnabled == nil || self.discoverEnabled.boolValue;
  AutumnOpsCredentialBundle *b = [self.client currentBundle:nil];
  NSString *certId = b.certId.length ? b.certId : (self.siteEntry.certId.length ? self.siteEntry.certId : @"无");
  NSString *fp = self.siteEntry.serverFingerprint.length ? self.siteEntry.serverFingerprint : @"-";

  for (UIView *v in self.siteInfoCard.contentStack.arrangedSubviews) {
    [self.siteInfoCard.contentStack removeArrangedSubview:v];
    [v removeFromSuperview];
  }
  [self.siteInfoCard.contentStack addArrangedSubview:[AutumnOpsSectionCardView kvRowWithKey:@"站点地址" value:self.client.baseUrl ?: @"-"]];
  [self.siteInfoCard.contentStack addArrangedSubview:[AutumnOpsSectionCardView kvRowWithKey:@"本机访问 IP" value:self.currentIp.length ? self.currentIp : @"未知"]];
  [self.siteInfoCard.contentStack addArrangedSubview:[AutumnOpsSectionCardView kvRowWithKey:@"本机证书标识" value:certId]];
  [self.siteInfoCard.contentStack addArrangedSubview:[AutumnOpsSectionCardView kvRowWithKey:@"服务端指纹" value:fp]];
  [self.siteInfoCard.contentStack addArrangedSubview:[AutumnOpsSectionCardView kvRowWithKey:@"有效设备数" value:[NSString stringWithFormat:@"%ld", (long)self.activeCount]]];

  [self.discoverCard setBodyText:discoverOn
      ? @"已打开：浏览器可访问发现页，扫码或点开链接即可引导安装运维客户端（如超然信）并添加本站。证书绑定成功后会自动关闭。"
      : @"已关闭：浏览器访问发现页将如同不存在（404），避免被探测；不影响本 App 内探测与运维。"];
  [AutumnOpsUIControls applyChipKind:discoverOn ? AutumnOpsChipKindOn : AutumnOpsChipKindOff
                              toChip:self.discoverChip
                                text:discoverOn ? @"发现已开" : @"发现已关"];
  [self.discoverActionBtn setTitle:discoverOn ? @"关闭" : @"打开" forState:UIControlStateNormal];
  [AutumnOpsUIControls applyStyle:discoverOn ? AutumnOpsButtonStyleOutlined : AutumnOpsButtonStyleFilled
                         toButton:self.discoverActionBtn];

  [self.gateCard setBodyText:gateOn
      ? @"已开启：进入后台与运维接口时，除超管账号外，客户端 IP 还必须在「管理 IP」名单中。"
      : @"已关闭：仅校验超管账号，不再核对管理 IP。账号泄露时攻击者可从任意 IP 进入后台。"];
  [AutumnOpsUIControls applyChipKind:gateOn ? AutumnOpsChipKindOn : AutumnOpsChipKindOff
                              toChip:self.gateChip
                                text:gateOn ? @"已开" : @"已关"];
  [self.gateActionBtn setTitle:gateOn ? @"关闭" : @"开启" forState:UIControlStateNormal];
  [AutumnOpsUIControls applyStyle:gateOn ? AutumnOpsButtonStyleOutlined : AutumnOpsButtonStyleFilled
                         toButton:self.gateActionBtn];

  BOOL configured = self.clearTokenConfigured.boolValue;
  [self.tokenCard setBodyText:configured
      ? @"用于关闭管理 IP 校验、删除「当前访问 IP」等危险操作的二次确认。右侧「保存」可校验；改成新值后点「修改」须验证原令牌。"
      : @"尚未配置时，关闭门禁、删除当前访问 IP 等危险操作无法执行。可在此直接设置令牌（需已入驻运维证书）；配置后也可随时修改。"];
  NSString *chipText = @"未填写";
  AutumnOpsChipKind chipKind = AutumnOpsChipKindEmpty;
  if (self.clearTokenStatus == AutumnOpsClearTokenUIServerUnset) { chipText = @"未配置"; chipKind = AutumnOpsChipKindUnset; }
  else if (self.clearTokenStatus == AutumnOpsClearTokenUIReady) { chipText = @"已就绪"; chipKind = AutumnOpsChipKindReady; }
  else if (self.clearTokenStatus == AutumnOpsClearTokenUISaved) { chipText = @"已保存"; chipKind = AutumnOpsChipKindSaved; }
  else if (self.clearTokenStatus == AutumnOpsClearTokenUIPending) { chipText = @"待保存"; chipKind = AutumnOpsChipKindPending; }
  else if (self.clearTokenStatus == AutumnOpsClearTokenUIError) { chipText = @"错误"; chipKind = AutumnOpsChipKindError; }
  [AutumnOpsUIControls applyChipKind:chipKind toChip:self.clearTokenStatusChip text:chipText];
  NSString *ph = configured ? @"输入令牌后保存校验，或修改后保存" : @"设置新的清除确认令牌";
  self.clearTokenField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:ph
      attributes:@{NSForegroundColorAttributeName : [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.7]}];
  [self _refreshClearTokenActionTitle];
  if (self.clearTokenError.length &&
      (self.clearTokenStatus == AutumnOpsClearTokenUIError || self.clearTokenStatus == AutumnOpsClearTokenUIServerUnset)) {
    self.clearTokenHint.text = self.clearTokenError;
    self.clearTokenHint.textColor = (self.clearTokenStatus == AutumnOpsClearTokenUIServerUnset)
        ? AutumnOpsUITheme.onSurfaceVariant
        : AutumnOpsUITheme.onErrorContainer;
    self.clearTokenHint.hidden = NO;
  } else {
    self.clearTokenHint.text = @"";
    self.clearTokenHint.hidden = YES;
  }

  self.claimBtn.hidden = self.currentIpInAdmin;
  [self.shareCard setBodyText:discoverOn
      ? @"生成发现链接。他人用运维客户端（如超然信）扫码或点开后可自动探测本站运维能力。"
      : @"发现页当前已关闭。仍可复制链接供运维客户端打开；浏览器打开将得到 404。"];
  self.shareUrlView.text = [AutumnOpsDiscover shareUrlForBase:self.client.baseUrl] ?: @"";
}

- (void)_clearTokenEdited {
  NSString *t = [self.clearTokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  self.clearTokenClearBtn.hidden = (t.length == 0);
  if ((self.clearTokenStatus == AutumnOpsClearTokenUIReady || self.clearTokenStatus == AutumnOpsClearTokenUISaved) &&
      self.verifiedClearToken.length &&
      ![t isEqualToString:self.verifiedClearToken]) {
    self.clearTokenStatus = AutumnOpsClearTokenUIPending;
    [AutumnOpsUIControls applyChipKind:AutumnOpsChipKindPending toChip:self.clearTokenStatusChip text:@"待保存"];
  }
  [self _refreshClearTokenActionTitle];
}

- (void)_refreshClearTokenActionTitle {
  BOOL configuring = self.clearTokenConfigured == nil || !self.clearTokenConfigured.boolValue;
  NSString *cur = self.clearTokenField.text ?: @"";
  self.clearTokenClearBtn.hidden = (cur.length == 0);
  // Flutter：configuring→配置；已校验且内容变化→修改；否则→保存
  BOOL showModify = !configuring && self.verifiedClearToken.length &&
      ![self.verifiedClearToken isEqualToString:cur];
  NSString *actionTitle = configuring ? @"配置" : (showModify ? @"修改" : @"保存");
  [self.clearTokenActionBtn setTitle:actionTitle forState:UIControlStateNormal];
  BOOL canSave = cur.length > 0 && self.busyDepth == 0;
  [AutumnOpsUIControls setControl:self.clearTokenActionBtn enabled:canSave];
}

- (void)_resetClearToken {
  self.clearTokenField.text = @"";
  self.clearTokenError = nil;
  BOOL serverUnset = self.clearTokenConfigured != nil && !self.clearTokenConfigured.boolValue;
  if (serverUnset) {
    self.clearTokenStatus = AutumnOpsClearTokenUIServerUnset;
    self.clearTokenError = @"尚未配置：填写新令牌后点右侧「保存」即可在本 App 完成配置";
  } else {
    self.clearTokenStatus = AutumnOpsClearTokenUIEmpty;
  }
  [self _reloadOverviewCards];
}

- (void)_showClearTokenError {
  if (self.clearTokenStatus != AutumnOpsClearTokenUIError &&
      self.clearTokenStatus != AutumnOpsClearTokenUIServerUnset) {
    return;
  }
  NSString *msg = self.clearTokenError;
  if (!msg.length) return;
  BOOL unset = self.clearTokenStatus == AutumnOpsClearTokenUIServerUnset;
  UIAlertController *a = [UIAlertController alertControllerWithTitle:unset ? @"尚未配置令牌" : @"操作失败"
                                                             message:msg
                                                      preferredStyle:UIAlertControllerStyleAlert];
  [a addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:a animated:YES completion:nil];
}

- (NSString *)_readyClearTokenOrNil {
  NSString *t = [self.clearTokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  BOOL verifiedState = self.clearTokenStatus == AutumnOpsClearTokenUIReady ||
      self.clearTokenStatus == AutumnOpsClearTokenUISaved;
  if (verifiedState && self.verifiedClearToken.length && [t isEqualToString:self.verifiedClearToken]) {
    return t;
  }
  return nil;
}

- (void)_gateActionTapped {
  BOOL gateOn = self.adminIpEnable.boolValue;
  if (gateOn) {
    if (self.clearTokenConfigured != nil && !self.clearTokenConfigured.boolValue) {
      [self _toast:@"请先配置清除确认令牌"];
      return;
    }
    __weak typeof(self) weakSelf = self;
    [self _confirm:@"关闭管理 IP 校验"
              body:@"关闭后不再校验「管理 IP」名单：任意来源 IP 只要拿到超管账号，即可进入后台与运维接口。"
                   @"管理 IP 列表仍会保留，但暂时不生效。仅在确认环境安全时关闭。确定？"
                ok:^{
      [weakSelf _resolveClearTokenWithReason:@"关闭管理 IP 校验后仅依赖超管账号，须提供清除确认令牌。"
                                  completion:^(NSString *token) {
        if (!token.length) {
          [weakSelf _toast:@"已取消：需要清除确认令牌"];
          return;
        }
        [weakSelf _applyAdminIpEnable:NO clearToken:token];
      }];
    }];
    return;
  }
  [self _applyAdminIpEnable:YES clearToken:[self _readyClearTokenOrNil]];
}

- (void)_applyAdminIpEnable:(BOOL)on clearToken:(NSString *)tok {
  [self _beginBusy];
  [self.client gateSetAdminIpEnable:on clearToken:tok completion:^(NSDictionary *data, NSError *error) {
    [self _endBusy];
    if (error) {
      [self _toast:error.localizedDescription];
      [self _reloadOverviewCards];
      return;
    }
    self.adminIpEnable = @(on);
    [self _refreshAll];
  }];
}

- (void)_discoverActionTapped {
  BOOL discoverOn = self.discoverEnabled == nil || self.discoverEnabled.boolValue;
  if (discoverOn) {
    [self _confirm:@"关闭公开发现页" body:@"关闭后浏览器访问 /ops/discover 将 404；App 探测仍可用。确认关闭？" ok:^{
      [self _applyDiscover:NO];
    }];
    return;
  }
  [self _applyDiscover:YES];
}

- (void)_applyDiscover:(BOOL)on {
  [self _beginBusy];
  [self.client gateSetDiscoverEnabled:on completion:^(NSDictionary *data, NSError *error) {
    [self _endBusy];
    if (error) {
      [self _toast:error.localizedDescription];
      [self _reloadOverviewCards];
      return;
    }
    self.discoverEnabled = @(on);
    [self _reloadOverviewCards];
  }];
}

- (void)_shareDiscover {
  NSString *u = [AutumnOpsDiscover shareUrlForBase:self.client.baseUrl];
  if (!u.length) { [self _toast:@"无法生成发现链接"]; return; }
  NSString *text = [NSString stringWithFormat:@"Autumn 运维发现入口（请用运维客户端打开，如超然信 https://chaoran.xin/）：\n%@", u];
  UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
  [self presentViewController:av animated:YES completion:nil];
}

- (void)_claimCurrentAdminIp {
  [self _beginBusy];
  [self.client adminIpAdd:nil claimCurrent:YES completion:^(AutumnOpsIpUpsertResult *result, NSError *error) {
    [self _endBusy];
    if (error) {
      [self _toast:error.localizedDescription];
      return;
    }
    NSString *ip = result.row.ip ?: @"";
    if (ip.length) [self _toast:[NSString stringWithFormat:@"已认领管理 IP：%@", ip]];
    [self _refreshAll];
  }];
}

- (void)_copyDiscover {
  NSString *u = [AutumnOpsDiscover shareUrlForBase:self.client.baseUrl];
  if (!u.length) { [self _toast:@"无法生成发现链接"]; return; }
  UIPasteboard.generalPasteboard.string = u;
  [self _toast:@"已复制发现链接"];
}

/// 对齐 Flutter `_saveClearToken`：配置 / 修改走 set；已就绪同值再点则 verify。无独立「校验」按钮。
- (void)_handleClearTokenFailure:(NSError *)error {
  NSString *msg = error.localizedDescription ?: @"操作失败";
  self.clearTokenError = msg;
  if ([msg containsString:@"尚未配置清除确认令牌"]) {
    self.clearTokenConfigured = @NO;
    self.clearTokenStatus = AutumnOpsClearTokenUIServerUnset;
  } else {
    self.clearTokenStatus = AutumnOpsClearTokenUIError;
  }
  [self _reloadOverviewCards];
}

- (void)_markClearTokenReady:(NSString *)token toast:(NSString *)toast {
  self.clearTokenConfigured = @YES;
  self.verifiedClearToken = token;
  self.clearTokenError = nil;
  self.clearTokenStatus = AutumnOpsClearTokenUISaved;
  [self _reloadOverviewCards];
  if (toast.length) [self _toast:toast];
  __weak typeof(self) weakSelf = self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) return;
    NSString *cur = [self.clearTokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([cur isEqualToString:token] && [self.verifiedClearToken isEqualToString:token]) {
      self.clearTokenStatus = AutumnOpsClearTokenUIReady;
      [self _reloadOverviewCards];
    }
  });
}

- (void)_saveClearToken {
  NSString *t = [self.clearTokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  AutumnOpsValidateResult *vr = [AutumnOpsValidators clearToken:t];
  if (!vr.ok) {
    self.clearTokenError = vr.error;
    self.clearTokenStatus = AutumnOpsClearTokenUIError;
    [self _reloadOverviewCards];
    return;
  }
  BOOL configuring = self.clearTokenConfigured == nil || !self.clearTokenConfigured.boolValue;
  BOOL modifying = !configuring &&
      (self.verifiedClearToken.length == 0 || ![self.verifiedClearToken isEqualToString:t]);

  if (configuring) {
    [self _beginBusy];
    [self.client gateSetClearToken:t oldClearToken:nil completion:^(NSDictionary *data, NSError *error) {
      [self _endBusy];
      if (error) { [self _handleClearTokenFailure:error]; return; }
      [self _markClearTokenReady:t toast:@"已配置清除确认令牌"];
    }];
    return;
  }

  if (modifying) {
    NSString *old = self.verifiedClearToken;
    if (old.length == 0 || [old isEqualToString:t]) {
      AutumnOpsSecureTokenFormController *vc =
          [[AutumnOpsSecureTokenFormController alloc] initWithTitle:@"验证原令牌"
                                                             reason:@"修改清除确认令牌须先验证原令牌。"
                                                         fieldLabel:@"原清除确认令牌"
                                                        fieldHelper:@"在系统加固 / 安全配置中查看"
                                                       confirmLabel:@"继续"
                                                        initialText:nil];
      __weak typeof(self) weakSelf = self;
      vc.onResult = ^(NSString *entered) {
        if (!entered.length) return;
        AutumnOpsValidateResult *oldVr = [AutumnOpsValidators clearToken:entered];
        if (!oldVr.ok) {
          [weakSelf _toast:oldVr.error ?: @"原令牌无效"];
          return;
        }
        [weakSelf _beginBusy];
        [weakSelf.client gateSetClearToken:t oldClearToken:entered completion:^(NSDictionary *data, NSError *error) {
          [weakSelf _endBusy];
          if (error) {
            [weakSelf _handleClearTokenFailure:error];
            return;
          }
          [weakSelf _markClearTokenReady:t toast:@"已更新清除确认令牌"];
        }];
      };
      UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
      nav.modalPresentationStyle = UIModalPresentationFormSheet;
      [self presentViewController:nav animated:YES completion:nil];
      return;
    }
    [self _beginBusy];
    [self.client gateSetClearToken:t oldClearToken:old completion:^(NSDictionary *data, NSError *error) {
      [self _endBusy];
      if (error) { [self _handleClearTokenFailure:error]; return; }
      [self _markClearTokenReady:t toast:@"已更新清除确认令牌"];
    }];
    return;
  }

  // 已配置且与已校验令牌一致：再核对一次（Flutter 合并到「保存」）
  [self _beginBusy];
  [self.client gateVerifyClearToken:t completion:^(NSDictionary *data, NSError *error) {
    [self _endBusy];
    if (error) { [self _handleClearTokenFailure:error]; return; }
    [self _markClearTokenReady:t toast:@"令牌已就绪"];
  }];
}
- (void)_openRecovery {
  AutumnOpsRecoveryViewController *vc = [[AutumnOpsRecoveryViewController alloc] initWithSiteTitle:self.siteEntry.title baseUrl:self.client.baseUrl];
  [self.navigationController pushViewController:vc animated:YES];
}

- (void)_markSiteUnenrolledAndClear {
  [self.client.store clear:nil];
  if (self.siteEntry && self.siteStore) {
    self.siteEntry.enrolled = NO;
    self.siteEntry.certId = nil;
    [self.siteStore upsertSite:self.siteEntry error:nil];
  }
}

@end
