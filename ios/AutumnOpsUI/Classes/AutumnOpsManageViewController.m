#import "AutumnOpsManageViewController.h"
#import "AutumnOpsRecoveryViewController.h"
#import "AutumnOpsShareHooks.h"
#import "AutumnOpsShieldPanelView.h"
#import "AutumnOpsJumpPanelView.h"
#import "AutumnOpsScrollableTabBar.h"
#import "AutumnOpsPageChromeView.h"
#import "AutumnOpsSectionCardView.h"
#import "AutumnOpsSitesViewController.h"
#import "AutumnOpsUIConfig.h"
#import "AutumnOpsUITheme.h"
#import "AutumnOpsUIControls.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

typedef NS_ENUM(NSInteger, AutumnOpsClearTokenUI) {
  AutumnOpsClearTokenUIEmpty = 0,
  AutumnOpsClearTokenUIPending,
  AutumnOpsClearTokenUISaved,
  AutumnOpsClearTokenUIReady,
  AutumnOpsClearTokenUIServerUnset,
  AutumnOpsClearTokenUIError,
};

@interface AutumnOpsManageViewController () <UITableViewDataSource, UITableViewDelegate>
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
@property (nonatomic, strong) UIView *runtimePanel;
@property (nonatomic, strong) UIView *adminIpPanel;
@property (nonatomic, strong) UIView *whitePanel;
@property (nonatomic, strong) UIView *blackPanel;
@property (nonatomic, strong) UIView *certPanel;

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

@property (nonatomic, strong) UITextView *runtimeText;

@property (nonatomic, strong) UITableView *adminTable;
@property (nonatomic, strong) UITableView *whiteTable;
@property (nonatomic, strong) UITableView *blackTable;
@property (nonatomic, strong) UITableView *certTable;
@property (nonatomic, copy) NSArray<AutumnOpsIpRow *> *adminRows;
@property (nonatomic, copy) NSArray<AutumnOpsIpRow *> *whiteRows;
@property (nonatomic, copy) NSArray<AutumnOpsIpRow *> *blackRows;
@property (nonatomic, copy) NSArray<NSDictionary *> *certs;
@property (nonatomic) NSInteger firewallCount;

@property (nonatomic, strong) UITextField *issueLabelField;
@property (nonatomic, strong) UITextField *passphraseField;
@property (nonatomic, strong) UILabel *claimHint;
@property (nonatomic, strong, nullable) AutumnOpsClaimIssueResult *lastIssue;

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
    _adminRows = @[];
    _whiteRows = @[];
    _blackRows = @[];
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
  UIAlertController *a = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
  [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:a animated:YES completion:nil];
}

- (void)_confirm:(NSString *)title body:(NSString *)body ok:(void (^)(void))ok {
  UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:body preferredStyle:UIAlertControllerStyleAlert];
  [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  [a addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { if (ok) ok(); }]];
  [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - Panels

- (UITableView *)_table {
  UITableView *t = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
  t.dataSource = self;
  t.delegate = self;
  t.rowHeight = UITableViewAutomaticDimension;
  t.estimatedRowHeight = 52;
  [t registerClass:[UITableViewCell class] forCellReuseIdentifier:@"row"];
  return t;
}

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

  // Runtime
  _runtimePanel = [UIView new];
  _runtimeText = [UITextView new];
  _runtimeText.editable = NO;
  _runtimeText.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  [_runtimePanel addSubview:_runtimeText];
  [_runtimeText mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_runtimePanel).insets(UIEdgeInsetsMake(8, 8, 8, 8));
  }];

  // IP panels
  _adminIpPanel = [self _ipPanelKind:0];
  _whitePanel = [self _ipPanelKind:1];
  _blackPanel = [self _ipPanelKind:2];

  __weak typeof(self) weakSelf = self;
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

  // Cert
  _certPanel = [UIView new];
  _issueLabelField = [UITextField new];
  _issueLabelField.borderStyle = UITextBorderStyleRoundedRect;
  _issueLabelField.text = @"新设备";
  _issueLabelField.placeholder = @"认领设备标签";
  _passphraseField = [UITextField new];
  _passphraseField.borderStyle = UITextBorderStyleRoundedRect;
  _passphraseField.secureTextEntry = YES;
  _passphraseField.placeholder = @"分享口令（导出/分享）";
  _claimHint = [UILabel new];
  _claimHint.numberOfLines = 0;
  _claimHint.font = [UIFont systemFontOfSize:12];
  UIButton *issue = [UIButton buttonWithType:UIButtonTypeSystem];
  [issue setTitle:@"签发认领码" forState:UIControlStateNormal];
  [issue addTarget:self action:@selector(_issueClaim) forControlEvents:UIControlEventTouchUpInside];
  UIButton *shareChat = [UIButton buttonWithType:UIButtonTypeSystem];
  [shareChat setTitle:@"分享到聊天" forState:UIControlStateNormal];
  [shareChat addTarget:self action:@selector(_shareToChat) forControlEvents:UIControlEventTouchUpInside];
  UIButton *exportBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [exportBtn setTitle:@"导出 .autumnops" forState:UIControlStateNormal];
  [exportBtn addTarget:self action:@selector(_exportFile) forControlEvents:UIControlEventTouchUpInside];
  UIButton *clearLocal = [UIButton buttonWithType:UIButtonTypeSystem];
  [clearLocal setTitle:@"清除本机凭证" forState:UIControlStateNormal];
  [clearLocal setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
  [clearLocal addTarget:self action:@selector(_clearLocal) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *certTop = [[UIStackView alloc] initWithArrangedSubviews:@[_issueLabelField, issue, _claimHint, _passphraseField, shareChat, exportBtn, clearLocal]];
  certTop.axis = UILayoutConstraintAxisVertical;
  certTop.spacing = 8;
  _certTable = [self _table];
  UIRefreshControl *certRC = [UIRefreshControl new];
  [certRC addTarget:self action:@selector(_pullRefreshAll) forControlEvents:UIControlEventValueChanged];
  _certTable.refreshControl = certRC;
  [_certPanel addSubview:certTop];
  [_certPanel addSubview:_certTable];
  [certTop mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.left.right.equalTo(_certPanel).insets(UIEdgeInsetsMake(12, 16, 0, 16));
  }];
  [_certTable mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(certTop.mas_bottom).offset(8);
    make.left.right.bottom.equalTo(_certPanel);
  }];
}

- (UIView *)_ipPanelKind:(NSInteger)kind {
  UIView *panel = [UIView new];
  UITableView *table = [self _table];
  UIRefreshControl *ipRC = [UIRefreshControl new];
  ipRC.tag = kind;
  [ipRC addTarget:self action:@selector(_pullRefreshIp:) forControlEvents:UIControlEventValueChanged];
  table.refreshControl = ipRC;
  UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
  [add setTitle:kind == 2 ? @"添加黑名单 IP" : @"添加本机/指定 IP" forState:UIControlStateNormal];
  add.tag = kind;
  [add addTarget:self action:@selector(_addIp:) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[add]];
  top.axis = UILayoutConstraintAxisVertical;
  if (kind == 2) {
    UILabel *fw = [UILabel new];
    fw.tag = 900;
    fw.font = [UIFont systemFontOfSize:13];
    fw.text = @"防火墙阈值：-";
    UIButton *setFw = [UIButton buttonWithType:UIButtonTypeSystem];
    [setFw setTitle:@"设置阈值" forState:UIControlStateNormal];
    [setFw addTarget:self action:@selector(_setFirewall) forControlEvents:UIControlEventTouchUpInside];
    [top addArrangedSubview:fw];
    [top addArrangedSubview:setFw];
  }
  [panel addSubview:top];
  [panel addSubview:table];
  [top mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.left.right.equalTo(panel).insets(UIEdgeInsetsMake(8, 16, 0, 16));
  }];
  [table mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(top.mas_bottom).offset(4);
    make.left.right.bottom.equalTo(panel);
  }];
  if (kind == 0) _adminTable = table;
  else if (kind == 1) _whiteTable = table;
  else _blackTable = table;
  return panel;
}

- (void)_tabChanged {
  for (UIView *v in self.contentHost.subviews) [v removeFromSuperview];
  NSArray *panels = @[self.overviewPanel, self.runtimePanel, self.adminIpPanel, self.whitePanel, self.blackPanel, self.shieldPanel, self.jumpPanel, self.certPanel];
  NSInteger i = self.tabs.selectedIndex;
  if (i < 0 || i >= (NSInteger)panels.count) return;
  UIView *p = panels[i];
  [self.contentHost addSubview:p];
  [p mas_makeConstraints:^(MASConstraintMaker *make) { make.edges.equalTo(self.contentHost); }];
  if (i == 1) [self _loadRuntime];
  if (i == 2) [self _loadIpKind:0];
  if (i == 3) [self _loadIpKind:1];
  if (i == 4) [self _loadIpKind:2];
  if (i == 5) [self.shieldPanel reload];
  if (i == 6) [self.jumpPanel reload];
}

#pragma mark - Refresh

- (void)_pullRefreshAll {
  [self _refreshAll];
}

- (void)_pullRefreshIp:(UIRefreshControl *)rc {
  [self _loadIpKind:rc.tag];
}

- (void)_endGlobalPullRefresh {
  if (self.overviewScroll.refreshControl.refreshing) {
    [self.overviewScroll.refreshControl endRefreshing];
  }
  if (self.certTable.refreshControl.refreshing) {
    [self.certTable.refreshControl endRefreshing];
  }
}

- (void)_endIpPullRefresh:(NSInteger)kind {
  UITableView *table = kind == 0 ? self.adminTable : (kind == 1 ? self.whiteTable : self.blackTable);
  if (table.refreshControl.refreshing) {
    [table.refreshControl endRefreshing];
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
    [self.certTable reloadData];
    NSInteger tab = self.tabs.selectedIndex;
    if (tab == 2) [self _loadIpKind:0];
    if (tab == 3) [self _loadIpKind:1];
    if (tab == 4) [self _loadIpKind:2];
    if (tab == 5) [self.shieldPanel reload];
    if (tab == 6) [self.jumpPanel reload];
  }];
}

- (void)_loadRuntime {
  [self _beginBusy];
  [self.client runtimeSnapshot:^(NSDictionary *data, NSError *error) {
    [self _endBusy];
    if (error) {
      self.runtimeText.text = error.localizedDescription;
      return;
    }
    NSData *json = [NSJSONSerialization dataWithJSONObject:data ?: @{} options:NSJSONWritingPrettyPrinted error:nil];
    self.runtimeText.text = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"";
  }];
}

- (void)_loadIpKind:(NSInteger)kind {
  [self _beginBusy];
  void (^done)(AutumnOpsIpPage *, NSError *) = ^(AutumnOpsIpPage *page, NSError *error) {
    [self _endBusy];
    [self _endIpPullRefresh:kind];
    if (error) { [self _toast:error.localizedDescription]; return; }
    if (kind == 0) { self.adminRows = page.list; [self.adminTable reloadData]; }
    else if (kind == 1) { self.whiteRows = page.list; [self.whiteTable reloadData]; }
    else { self.blackRows = page.list; [self.blackTable reloadData]; }
  };
  if (kind == 0) [self.client adminIpListPage:1 limit:100 completion:done];
  else if (kind == 1) [self.client ipWhiteListPage:1 limit:100 completion:done];
  else {
    [self.client ipBlackListPage:1 limit:100 completion:done];
    [self.client ipBlackFirewallCount:^(NSInteger value, NSError *error) {
      self.firewallCount = value;
      UILabel *fw = [self.blackPanel viewWithTag:900];
      if ([fw isKindOfClass:[UILabel class]]) fw.text = [NSString stringWithFormat:@"防火墙阈值：%ld", (long)value];
    }];
  }
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
    NSString *tok = [self _readyClearTokenOrNil];
    if (!tok.length) {
      [self _toast:@"关闭管理 IP 门禁需先在概览校验清除确认令牌"];
      return;
    }
    [self _confirm:@"关闭管理 IP 校验"
              body:@"关闭后不再校验「管理 IP」名单：任意来源 IP 只要拿到超管账号，即可进入后台与运维接口。"
                   @"管理 IP 列表仍会保留，但暂时不生效。仅在确认环境安全时关闭。确定？"
                ok:^{
      [self _applyAdminIpEnable:NO clearToken:tok];
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
  [self.client adminIpAdd:nil claimCurrent:YES completion:^(NSDictionary *data, NSError *error) {
    [self _endBusy];
    if (error) [self _toast:error.localizedDescription];
    else [self _refreshAll];
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
      UIAlertController *a = [UIAlertController alertControllerWithTitle:@"验证原令牌"
                                                                 message:@"修改清除确认令牌须先验证原令牌。"
                                                          preferredStyle:UIAlertControllerStyleAlert];
      [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.secureTextEntry = YES;
        tf.placeholder = @"原清除确认令牌";
      }];
      [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
      [a addAction:[UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *entered = [a.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        AutumnOpsValidateResult *oldVr = [AutumnOpsValidators clearToken:entered];
        if (!oldVr.ok) { [self _toast:oldVr.error ?: @"原令牌无效"]; return; }
        [self _beginBusy];
        [self.client gateSetClearToken:t oldClearToken:entered completion:^(NSDictionary *data, NSError *error) {
          [self _endBusy];
          if (error) { [self _handleClearTokenFailure:error]; return; }
          [self _markClearTokenReady:t toast:@"已更新清除确认令牌"];
        }];
      }]];
      [self presentViewController:a animated:YES completion:nil];
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

#pragma mark - IP

- (void)_addIp:(UIButton *)sender {
  NSInteger kind = sender.tag;
  BOOL claimHidden = (kind == 0 && self.currentIpInAdmin) || (kind == 1 && (self.currentIpInAdmin || self.currentIpInWhite));
  NSString *msg = claimHidden
      ? @"请填写 IP（当前访问 IP 已在名单中，勿留空认领）"
      : @"留空表示认领当前访问 IP（黑名单须填写）";
  UIAlertController *a = [UIAlertController alertControllerWithTitle:@"添加 IP" message:msg preferredStyle:UIAlertControllerStyleAlert];
  [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"IP"; }];
  [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  [a addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *ip = [a.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (claimHidden && !ip.length) {
      [self _toast:@"当前 IP 已在名单中，请填写其它 IP"];
      return;
    }
    [self _beginBusy];
    AutumnOpsDictBlock done = ^(NSDictionary *data, NSError *error) {
      [self _endBusy];
      if (error) [self _toast:error.localizedDescription];
      else {
        [self _loadIpKind:kind];
        [self _refreshAll];
      }
    };
    if (kind == 0) [self.client adminIpAdd:ip.length ? ip : nil claimCurrent:ip.length == 0 completion:done];
    else if (kind == 1) [self.client ipWhiteAdd:ip.length ? ip : nil claimCurrent:ip.length == 0 completion:done];
    else {
      if (!ip.length) { [self _endBusy]; [self _toast:@"黑名单须填写 IP"]; return; }
      [self.client ipBlackAdd:ip completion:done];
    }
  }]];
  [self presentViewController:a animated:YES completion:nil];
}

- (void)_setFirewall {
  UIAlertController *a = [UIAlertController alertControllerWithTitle:@"防火墙阈值" message:nil preferredStyle:UIAlertControllerStyleAlert];
  [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.keyboardType = UIKeyboardTypeNumberPad;
    tf.text = [NSString stringWithFormat:@"%ld", (long)self.firewallCount];
  }];
  [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSInteger n = a.textFields.firstObject.text.integerValue;
    if (n < 500) { [self _toast:@"防火墙阈值最小 500"]; return; }
    [self _beginBusy];
    [self.client ipBlackSetFirewallCount:n completion:^(NSInteger value, NSError *error) {
      [self _endBusy];
      if (error) [self _toast:error.localizedDescription];
      else [self _loadIpKind:2];
    }];
  }]];
  [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - Cert

- (void)_issueClaim {
  NSString *label = self.issueLabelField.text.length ? self.issueLabelField.text : @"新设备";
  [self _beginBusy];
  [self.client certIssueWithLabel:label completion:^(AutumnOpsClaimIssueResult *result, NSError *error) {
    [self _endBusy];
    if (error) { [self _toast:error.localizedDescription]; return; }
    self.lastIssue = result;
    self.claimHint.text = [NSString stringWithFormat:@"认领码（仅显示一次）：\n%@", result.claimSecret];
    UIPasteboard.generalPasteboard.string = result.claimSecret;
    [self _toast:@"认领码已复制"];
    [self _refreshAll];
  }];
}

- (void)_shareToChat {
  AutumnOpsShareToChatBlock hook = AutumnOpsShareHooks.toChat;
  if (!hook) {
    [self _toast:@"宿主未注入分享钩子"];
    return;
  }
  NSString *pass = self.passphraseField.text;
  AutumnOpsValidateResult *vr = [AutumnOpsValidators sharePassphrase:pass];
  if (!vr.ok) { [self _toast:vr.error]; return; }
  NSError *err = nil;
  NSString *wrapped = [self.client exportWrappedWithPassphrase:pass error:&err];
  if (!wrapped) { [self _toast:err.localizedDescription]; return; }
  AutumnOpsCredentialBundle *b = [self.client currentBundle:nil];
  NSDictionary *content = [AutumnOpsPayload toMessageMapWithWrapped:wrapped
                                                            baseUrl:self.client.baseUrl
                                                             siteId:b.siteId
                                                             certId:b.certId
                                                 serverFingerprint:b.serverFingerprint
                                                       createdAtMs:@((long long)([[NSDate date] timeIntervalSince1970] * 1000))];
  hook(self, content, ^(BOOL ok) {
    if (ok) [self _toast:@"已发送"];
  });
}

- (void)_exportFile {
  NSString *pass = self.passphraseField.text;
  AutumnOpsValidateResult *vr = [AutumnOpsValidators sharePassphrase:pass];
  if (!vr.ok) { [self _toast:vr.error]; return; }
  NSError *err = nil;
  NSString *wrapped = [self.client exportWrappedWithPassphrase:pass error:&err];
  if (!wrapped) { [self _toast:err.localizedDescription]; return; }
  AutumnOpsCredentialBundle *b = [self.client currentBundle:nil];
  NSDictionary *map = [AutumnOpsPayload toMessageMapWithWrapped:wrapped
                                                        baseUrl:self.client.baseUrl
                                                         siteId:b.siteId
                                                         certId:b.certId
                                             serverFingerprint:b.serverFingerprint
                                                   createdAtMs:@((long long)([[NSDate date] timeIntervalSince1970] * 1000))];
  NSData *data = [NSJSONSerialization dataWithJSONObject:map options:NSJSONWritingPrettyPrinted error:nil];
  NSURL *tmp = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ops-%@.%@", b.certId ?: @"cred", [AutumnOpsPayload fileExtension]]]];
  [data writeToURL:tmp atomically:YES];
  UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[tmp] applicationActivities:nil];
  av.popoverPresentationController.sourceView = self.view;
  [self presentViewController:av animated:YES completion:nil];
}

- (void)_clearLocal {
  [self _confirm:@"清除本机凭证" body:@"仅删除本机密钥，不吊销服务端证书。清除后需重新导入或入驻。" ok:^{
    [self _markSiteUnenrolledAndClear];
    AutumnOpsRecoveryViewController *vc = [[AutumnOpsRecoveryViewController alloc] initWithSiteTitle:self.siteEntry.title baseUrl:self.client.baseUrl];
    NSMutableArray *stack = [(self.navigationController.viewControllers ?: @[]) mutableCopy];
    if (stack.count) [stack removeLastObject];
    [stack addObject:vc];
    [self.navigationController setViewControllers:stack animated:YES];
  }];
}

#pragma mark - Table

- (NSInteger)_kindForTable:(UITableView *)table {
  if (table == self.adminTable) return 0;
  if (table == self.whiteTable) return 1;
  if (table == self.blackTable) return 2;
  if (table == self.certTable) return 3;
  return -1;
}

- (NSArray *)_rowsForKind:(NSInteger)kind {
  if (kind == 0) return self.adminRows;
  if (kind == 1) return self.whiteRows;
  if (kind == 2) return self.blackRows;
  return self.certs;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [self _rowsForKind:[self _kindForTable:tableView]].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row" forIndexPath:indexPath];
  cell.textLabel.numberOfLines = 0;
  cell.accessoryType = UITableViewCellAccessoryNone;
  NSInteger kind = [self _kindForTable:tableView];
  if (kind == 3) {
    NSDictionary *c = self.certs[indexPath.row];
    BOOL revoked = [c[@"revoked"] boolValue];
    cell.textLabel.text = [NSString stringWithFormat:@"%@\n%@%@",
                           c[@"certId"] ?: @"-",
                           c[@"label"] ?: @"",
                           revoked ? @" · 已吊销" : @" · 有效"];
    cell.textLabel.textColor = revoked ? UIColor.secondaryLabelColor : UIColor.labelColor;
  } else {
    AutumnOpsIpRow *r = [self _rowsForKind:kind][indexPath.row];
    NSString *extra = @"";
    if (kind == 2) extra = [NSString stringWithFormat:@" available=%@", r.available ?: @"-"];
    else if (r.forbidden) extra = [r.forbidden boolValue] ? @" · 禁用" : @" · 启用";
    cell.textLabel.text = [NSString stringWithFormat:@"%@%@", r.ip, extra];
  }
  return cell;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSInteger kind = [self _kindForTable:tableView];
  if (kind < 0) return nil;
  __weak typeof(self) weakSelf = self;
  if (kind == 3) {
    NSDictionary *c = self.certs[indexPath.row];
    if ([c[@"revoked"] boolValue]) return nil;
    NSString *cid = [NSString stringWithFormat:@"%@", c[@"certId"] ?: @""];
    UIContextualAction *rev = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"吊销" handler:^(__kindof UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
      [weakSelf _confirm:@"吊销证书" body:[NSString stringWithFormat:@"吊销 %@？若为最后一张有效证需走恢复流程。", cid] ok:^{
        [weakSelf _beginBusy];
        [weakSelf.client certRevoke:cid completion:^(AutumnOpsRevokeResult *result, NSError *error) {
          [weakSelf _endBusy];
          if (error) [weakSelf _toast:error.localizedDescription];
          else {
            if (result.lastCert) {
              [weakSelf _markSiteUnenrolledAndClear];
              AutumnOpsRecoveryViewController *vc = [[AutumnOpsRecoveryViewController alloc] initWithSiteTitle:weakSelf.siteEntry.title baseUrl:weakSelf.client.baseUrl];
              NSMutableArray *stack = [(weakSelf.navigationController.viewControllers ?: @[]) mutableCopy];
              if (stack.count) [stack removeLastObject];
              [stack addObject:vc];
              [weakSelf.navigationController setViewControllers:stack animated:YES];
            } else {
              [weakSelf _refreshAll];
            }
          }
        }];
      }];
      completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[rev]];
  }
  AutumnOpsIpRow *row = [self _rowsForKind:kind][indexPath.row];
  UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除" handler:^(__kindof UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
    void (^doRemove)(NSString *) = ^(NSString *tok) {
      [weakSelf _beginBusy];
      AutumnOpsDictBlock done = ^(NSDictionary *data, NSError *error) {
        [weakSelf _endBusy];
        if (error) [weakSelf _toast:error.localizedDescription];
        else [weakSelf _loadIpKind:kind];
      };
      if (kind == 0) [weakSelf.client adminIpRemove:row.ip clearToken:tok completion:done];
      else if (kind == 1) [weakSelf.client ipWhiteRemove:row.ip clearToken:tok completion:done];
      else [weakSelf.client ipBlackRemove:row.ip completion:done];
    };
    if (kind == 0 || kind == 1) {
      NSString *tok = [weakSelf _readyClearTokenOrNil];
      if ([row.ip isEqualToString:weakSelf.currentIp] && !tok.length) {
        [weakSelf _toast:@"删除当前访问 IP 需先校验清除确认令牌（概览页）"];
        completionHandler(NO);
        return;
      }
      doRemove(tok);
    } else {
      doRemove(nil);
    }
    completionHandler(YES);
  }];
  return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  NSInteger kind = [self _kindForTable:tableView];
  if (kind == 0 || kind == 1) {
    AutumnOpsIpRow *row = [self _rowsForKind:kind][indexPath.row];
    BOOL next = !(row.forbidden.boolValue);
    [self _beginBusy];
    AutumnOpsDictBlock done = ^(NSDictionary *data, NSError *error) {
      [self _endBusy];
      if (error) [self _toast:error.localizedDescription];
      else [self _loadIpKind:kind];
    };
    if (kind == 0) [self.client adminIpSetForbidden:row.ip forbidden:next completion:done];
    else [self.client ipWhiteSetForbidden:row.ip forbidden:next completion:done];
  } else if (kind == 2) {
    AutumnOpsIpRow *row = [self _rowsForKind:kind][indexPath.row];
    NSInteger next = row.available.integerValue == 0 ? 1 : 0;
    [self _beginBusy];
    [self.client ipBlackSetAvailable:row.ip available:next completion:^(NSDictionary *data, NSError *error) {
      [self _endBusy];
      if (error) [self _toast:error.localizedDescription];
      else [self _loadIpKind:2];
    }];
  }
}

@end
