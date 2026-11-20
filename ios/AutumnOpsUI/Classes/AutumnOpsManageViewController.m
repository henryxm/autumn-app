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
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

typedef NS_ENUM(NSInteger, AutumnOpsClearTokenUI) {
  AutumnOpsClearTokenUIEmpty = 0,
  AutumnOpsClearTokenUIPending,
  AutumnOpsClearTokenUIReady,
  AutumnOpsClearTokenUIServerUnset,
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
@property (nonatomic, strong) UIBarButtonItem *refreshBarItem;
@property (nonatomic, strong) UIButton *chromeSitesBtn;
@property (nonatomic, strong) UIButton *chromeRefreshBtn;

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
@property (nonatomic, strong) UILabel *discoverChip;
@property (nonatomic, strong) UILabel *gateChip;
@property (nonatomic, strong) UIButton *discoverActionBtn;
@property (nonatomic, strong) UIButton *gateActionBtn;
@property (nonatomic, strong) UIButton *claimBtn;
@property (nonatomic, strong) UILabel *shareUrlLabel;
@property (nonatomic, strong) UILabel *clearTokenStatusChip;
@property (nonatomic, strong) UIButton *clearTokenActionBtn;
@property (nonatomic) NSInteger activeCount;

@property (nonatomic, strong) UITextField *clearTokenField;
@property (nonatomic, strong) UILabel *clearTokenHint;

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

  self.sitesBarItem = [[UIBarButtonItem alloc] initWithTitle:@"站点" style:UIBarButtonItemStylePlain target:self action:@selector(_goSites)];
  self.refreshBarItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(_refreshAll)];
  self.navigationItem.rightBarButtonItems = @[self.refreshBarItem, self.sitesBarItem];

  BOOL embed = [AutumnOpsPageChromeView shouldEmbedInViewController:self];
  UIView *topAnchorView = nil;
  if (embed) {
    self.navigationItem.rightBarButtonItems = nil;
    self.navigationItem.title = nil;
    _pageChrome = [AutumnOpsPageChromeView new];
    _pageChrome.titleText = title;
    _pageChrome.showsBack = YES;
    __weak typeof(self) weakSelf = self;
    _pageChrome.onBack = ^{ [AutumnOpsPageChromeView performBackFromViewController:weakSelf]; };
    _chromeSitesBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_chromeSitesBtn setTitle:@"站点" forState:UIControlStateNormal];
    _chromeSitesBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [_chromeSitesBtn addTarget:self action:@selector(_goSites) forControlEvents:UIControlEventTouchUpInside];
    _chromeRefreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_chromeRefreshBtn setImage:[UIImage systemImageNamed:@"arrow.clockwise"] forState:UIControlStateNormal];
    _chromeRefreshBtn.tintColor = UIColor.labelColor;
    [_chromeRefreshBtn addTarget:self action:@selector(_refreshAll) forControlEvents:UIControlEventTouchUpInside];
    [_pageChrome.rightStack addArrangedSubview:_chromeSitesBtn];
    [_pageChrome.rightStack addArrangedSubview:_chromeRefreshBtn];
    [self.view addSubview:_pageChrome];
    [_pageChrome mas_makeConstraints:^(MASConstraintMaker *make) {
      make.left.right.equalTo(self.view);
      make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
      make.height.mas_equalTo(44);
    }];
    topAnchorView = _pageChrome;
  }

  _tabs = [[AutumnOpsScrollableTabBar alloc] initWithItems:@[@"概览", @"运行", @"管理IP", @"白名单", @"黑名单", @"盾牌", @"跳转", @"证书"]];
  _tabs.selectedIndex = 0;
  [_tabs addTarget:self action:@selector(_tabChanged) forControlEvents:UIControlEventValueChanged];

  _statusBar = [UIView new];
  _statusBar.backgroundColor = [UIColor tertiarySystemFillColor];
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
  self.refreshBarItem.enabled = enabled;
  self.chromeSitesBtn.enabled = enabled;
  self.chromeRefreshBtn.enabled = enabled;
  self.discoverActionBtn.enabled = enabled;
  self.gateActionBtn.enabled = enabled;
  self.claimBtn.enabled = enabled;
  self.clearTokenActionBtn.enabled = enabled;
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

- (UIButton *)_filledButton:(NSString *)title action:(SEL)action {
  UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
  [b setTitle:title forState:UIControlStateNormal];
  b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  b.backgroundColor = [UIColor colorWithRed:0x15 / 255.0 green:0x65 / 255.0 blue:0xC0 / 255.0 alpha:1];
  b.layer.cornerRadius = 8;
  b.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
  [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
  return b;
}

- (UIButton *)_outlinedButton:(NSString *)title action:(SEL)action {
  UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
  [b setTitle:title forState:UIControlStateNormal];
  b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
  b.layer.cornerRadius = 8;
  b.layer.borderWidth = 1;
  b.layer.borderColor = UIColor.separatorColor.CGColor;
  b.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
  [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
  return b;
}

- (void)_buildPanels {
  // Overview — Flutter section cards
  _overviewPanel = [UIView new];
  _overviewScroll = [UIScrollView new];
  _overviewScroll.alwaysBounceVertical = YES;
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
  _discoverChip = [AutumnOpsSectionCardView statusChipWithText:@"发现已开" on:YES];
  _discoverActionBtn = [self _outlinedButton:@"关闭" action:@selector(_discoverActionTapped)];
  UIView *discSpacer = [UIView new];
  [discSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  UIStackView *discRow = [[UIStackView alloc] initWithArrangedSubviews:@[_discoverChip, discSpacer, _discoverActionBtn]];
  discRow.axis = UILayoutConstraintAxisHorizontal;
  discRow.alignment = UIStackViewAlignmentCenter;
  discRow.spacing = 8;
  [_discoverCard.contentStack addArrangedSubview:discRow];
  [_overviewStack addArrangedSubview:_discoverCard];

  _gateCard = [[AutumnOpsSectionCardView alloc] initWithTitle:@"管理 IP 校验（门禁）" body:@""];
  _gateChip = [AutumnOpsSectionCardView statusChipWithText:@"已开" on:YES];
  _gateActionBtn = [self _outlinedButton:@"关闭" action:@selector(_gateActionTapped)];
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
  _clearTokenStatusChip = [AutumnOpsSectionCardView statusChipWithText:@"未填写" on:NO];
  UIStackView *tokTitleExtra = [[UIStackView alloc] initWithArrangedSubviews:@[[UIView new], _clearTokenStatusChip]];
  tokTitleExtra.axis = UILayoutConstraintAxisHorizontal;
  [_tokenCard.contentStack addArrangedSubview:tokTitleExtra];
  _clearTokenField = [UITextField new];
  _clearTokenField.secureTextEntry = YES;
  _clearTokenField.placeholder = @"输入令牌后保存校验，或修改后保存";
  _clearTokenField.font = [UIFont systemFontOfSize:15];
  _clearTokenActionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [_clearTokenActionBtn setTitle:@"保存" forState:UIControlStateNormal];
  _clearTokenActionBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  [_clearTokenActionBtn addTarget:self action:@selector(_saveClearToken) forControlEvents:UIControlEventTouchUpInside];
  UIView *tokBar = [UIView new];
  tokBar.backgroundColor = UIColor.systemBackgroundColor;
  tokBar.layer.cornerRadius = 12;
  tokBar.layer.borderWidth = 1;
  tokBar.layer.borderColor = UIColor.separatorColor.CGColor;
  [tokBar addSubview:_clearTokenField];
  [tokBar addSubview:_clearTokenActionBtn];
  UIView *tokDivider = [UIView new];
  tokDivider.backgroundColor = UIColor.separatorColor;
  [tokBar addSubview:tokDivider];
  [_clearTokenField mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(tokBar).offset(14);
    make.top.bottom.equalTo(tokBar);
    make.right.equalTo(tokDivider.mas_left).offset(-8);
    make.height.mas_equalTo(52);
  }];
  [tokDivider mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(tokBar);
    make.width.mas_equalTo(1);
    make.height.mas_equalTo(28);
    make.right.equalTo(_clearTokenActionBtn.mas_left).offset(-4);
  }];
  [_clearTokenActionBtn mas_makeConstraints:^(MASConstraintMaker *make) {
    make.right.equalTo(tokBar).offset(-8);
    make.centerY.equalTo(tokBar);
    make.width.mas_greaterThanOrEqualTo(56);
  }];
  [_tokenCard.contentStack addArrangedSubview:tokBar];
  _clearTokenHint = [UILabel new];
  _clearTokenHint.numberOfLines = 0;
  _clearTokenHint.font = [UIFont systemFontOfSize:12];
  _clearTokenHint.textColor = UIColor.secondaryLabelColor;
  [_tokenCard.contentStack addArrangedSubview:_clearTokenHint];
  UIButton *verifyTok = [UIButton buttonWithType:UIButtonTypeSystem];
  [verifyTok setTitle:@"校验令牌" forState:UIControlStateNormal];
  [verifyTok addTarget:self action:@selector(_verifyClearToken) forControlEvents:UIControlEventTouchUpInside];
  [_tokenCard.contentStack addArrangedSubview:verifyTok];
  [_overviewStack addArrangedSubview:_tokenCard];

  _claimBtn = [self _filledButton:@"认领当前 IP 为管理 IP" action:@selector(_claimCurrentAdminIp)];
  [_overviewStack addArrangedSubview:_claimBtn];

  _shareCard = [[AutumnOpsSectionCardView alloc] initWithTitle:@"分享管理入口" body:@""];
  _shareUrlLabel = [UILabel new];
  _shareUrlLabel.font = [UIFont systemFontOfSize:13];
  _shareUrlLabel.numberOfLines = 0;
  [_shareCard.contentStack addArrangedSubview:_shareUrlLabel];
  UIButton *copyBtn = [self _outlinedButton:@"复制链接" action:@selector(_copyDiscover)];
  UIButton *shareBtn = [self _filledButton:@"分享" action:@selector(_shareDiscover)];
  UIStackView *shareRow = [[UIStackView alloc] initWithArrangedSubviews:@[copyBtn, shareBtn]];
  shareRow.axis = UILayoutConstraintAxisHorizontal;
  shareRow.spacing = 8;
  shareRow.distribution = UIStackViewDistributionFillEqually;
  [_shareCard.contentStack addArrangedSubview:shareRow];
  [_overviewStack addArrangedSubview:_shareCard];

  UIButton *recovery = [self _outlinedButton:@"丢钥 / 无法入驻时如何恢复" action:@selector(_openRecovery)];
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

- (void)_refreshAll {
  [self _beginBusy];
  [self.client ensureSession:^(NSError *error) {
    if (error) {
      [self _endBusy];
      [self _setStatus:error.localizedDescription];
      return;
    }
    [self.client gateGet:^(NSDictionary *data, NSError *err) {
      if (err) {
        [self _endBusy];
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
        self.clearTokenHint.text = @"已配置：校验通过后才可做敏感操作";
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
  self.discoverChip.text = [NSString stringWithFormat:@"  %@  ", discoverOn ? @"发现已开" : @"发现已关"];
  self.discoverChip.backgroundColor = discoverOn
      ? [UIColor.systemTealColor colorWithAlphaComponent:0.22]
      : [UIColor.systemRedColor colorWithAlphaComponent:0.18];
  [self.discoverActionBtn setTitle:discoverOn ? @"关闭" : @"打开" forState:UIControlStateNormal];
  if (discoverOn) {
    self.discoverActionBtn.backgroundColor = UIColor.clearColor;
    self.discoverActionBtn.layer.borderWidth = 1;
    [self.discoverActionBtn setTitleColor:[UIColor colorWithRed:0x15 / 255.0 green:0x65 / 255.0 blue:0xC0 / 255.0 alpha:1] forState:UIControlStateNormal];
  } else {
    self.discoverActionBtn.backgroundColor = [UIColor colorWithRed:0x15 / 255.0 green:0x65 / 255.0 blue:0xC0 / 255.0 alpha:1];
    self.discoverActionBtn.layer.borderWidth = 0;
    [self.discoverActionBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  }

  [self.gateCard setBodyText:gateOn
      ? @"已开启：进入后台与运维接口时，除超管账号外，客户端 IP 还必须在「管理 IP」名单中。"
      : @"已关闭：仅校验超管账号，不再核对管理 IP。账号泄露时攻击者可从任意 IP 进入后台。"];
  self.gateChip.text = [NSString stringWithFormat:@"  %@  ", gateOn ? @"已开" : @"已关"];
  self.gateChip.backgroundColor = gateOn
      ? [UIColor.systemTealColor colorWithAlphaComponent:0.22]
      : [UIColor.systemRedColor colorWithAlphaComponent:0.18];
  [self.gateActionBtn setTitle:gateOn ? @"关闭" : @"开启" forState:UIControlStateNormal];
  if (gateOn) {
    self.gateActionBtn.backgroundColor = UIColor.clearColor;
    self.gateActionBtn.layer.borderWidth = 1;
    [self.gateActionBtn setTitleColor:[UIColor colorWithRed:0x15 / 255.0 green:0x65 / 255.0 blue:0xC0 / 255.0 alpha:1] forState:UIControlStateNormal];
  } else {
    self.gateActionBtn.backgroundColor = [UIColor colorWithRed:0x15 / 255.0 green:0x65 / 255.0 blue:0xC0 / 255.0 alpha:1];
    self.gateActionBtn.layer.borderWidth = 0;
    [self.gateActionBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  }

  BOOL configured = self.clearTokenConfigured.boolValue;
  [self.tokenCard setBodyText:configured
      ? @"用于关闭管理 IP 校验、删除「当前访问 IP」等危险操作的二次确认。右侧「保存」可校验；改成新值后点「修改」须验证原令牌。"
      : @"尚未配置时，关闭门禁、删除当前访问 IP 等危险操作无法执行。可在此直接设置令牌（需已入驻运维证书）；配置后也可随时修改。"];
  NSString *chipText = @"未填写";
  BOOL chipOn = NO;
  if (self.clearTokenStatus == AutumnOpsClearTokenUIServerUnset) { chipText = @"未配置"; chipOn = NO; }
  else if (self.clearTokenStatus == AutumnOpsClearTokenUIReady) { chipText = @"已就绪"; chipOn = YES; }
  else if (self.clearTokenStatus == AutumnOpsClearTokenUIPending) { chipText = @"待保存"; chipOn = YES; }
  self.clearTokenStatusChip.text = [NSString stringWithFormat:@"  %@  ", chipText];
  self.clearTokenStatusChip.backgroundColor = chipOn
      ? [UIColor.systemTealColor colorWithAlphaComponent:0.22]
      : [UIColor.tertiarySystemFillColor colorWithAlphaComponent:1];
  [self.clearTokenActionBtn setTitle:configured ? (self.clearTokenStatus == AutumnOpsClearTokenUIReady ? @"修改" : @"保存") : @"配置" forState:UIControlStateNormal];

  self.claimBtn.hidden = self.currentIpInAdmin;
  [self.shareCard setBodyText:discoverOn
      ? @"生成发现链接。他人用运维客户端（如超然信）扫码或点开后可自动探测本站运维能力。"
      : @"发现页当前已关闭。仍可复制链接供运维客户端打开；浏览器打开将得到 404。"];
  self.shareUrlLabel.text = [AutumnOpsDiscover shareUrlForBase:self.client.baseUrl] ?: @"";
}

- (NSString *)_readyClearTokenOrNil {
  NSString *t = [self.clearTokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (self.clearTokenStatus == AutumnOpsClearTokenUIReady && self.verifiedClearToken.length && [t isEqualToString:self.verifiedClearToken]) {
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
    [self _confirm:@"关闭管理 IP 门禁" body:@"关闭后未列入管理 IP 的访问将无法进入运维。确认关闭？" ok:^{
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

- (void)_verifyClearToken {
  NSString *t = [self.clearTokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  AutumnOpsValidateResult *vr = [AutumnOpsValidators clearToken:t];
  if (!vr.ok) { self.clearTokenHint.text = vr.error; return; }
  [self _beginBusy];
  [self.client gateVerifyClearToken:t completion:^(NSDictionary *data, NSError *error) {
    [self _endBusy];
    if (error) {
      self.clearTokenStatus = AutumnOpsClearTokenUIPending;
      self.clearTokenHint.text = error.localizedDescription;
      return;
    }
    self.clearTokenStatus = AutumnOpsClearTokenUIReady;
    self.verifiedClearToken = t;
    self.clearTokenHint.text = @"令牌已就绪";
    [self _reloadOverviewCards];
  }];
}

- (void)_saveClearToken {
  NSString *t = [self.clearTokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  AutumnOpsValidateResult *vr = [AutumnOpsValidators clearToken:t];
  if (!vr.ok) { self.clearTokenHint.text = vr.error; return; }
  BOOL configured = self.clearTokenConfigured.boolValue;
  if (configured && self.clearTokenStatus != AutumnOpsClearTokenUIReady) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"验证原清除确认令牌" message:@"修改令牌前需验证当前令牌" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.secureTextEntry = YES; tf.placeholder = @"原令牌"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      NSString *old = a.textFields.firstObject.text;
      [self _beginBusy];
      [self.client gateSetClearToken:t oldClearToken:old completion:^(NSDictionary *data, NSError *error) {
        [self _endBusy];
        if (error) { self.clearTokenHint.text = error.localizedDescription; return; }
        self.clearTokenConfigured = @YES;
        self.clearTokenStatus = AutumnOpsClearTokenUIReady;
        self.verifiedClearToken = t;
        self.clearTokenHint.text = @"已保存并就绪";
        [self _reloadOverviewCards];
      }];
    }]];
    [self presentViewController:a animated:YES completion:nil];
    return;
  }
  NSString *old = (self.clearTokenStatus == AutumnOpsClearTokenUIReady) ? self.verifiedClearToken : nil;
  [self _beginBusy];
  [self.client gateSetClearToken:t oldClearToken:old completion:^(NSDictionary *data, NSError *error) {
    [self _endBusy];
    if (error) { self.clearTokenHint.text = error.localizedDescription; return; }
    self.clearTokenConfigured = @YES;
    self.clearTokenStatus = AutumnOpsClearTokenUIReady;
    self.verifiedClearToken = t;
    self.clearTokenHint.text = @"已保存并就绪";
    [self _reloadOverviewCards];
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
