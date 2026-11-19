#import "AutumnOpsManageViewController.h"
#import "AutumnOpsRecoveryViewController.h"
#import "AutumnOpsShareHooks.h"
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
@property (nonatomic, strong) UISegmentedControl *tabs;
@property (nonatomic, strong) UIScrollView *tabScroll;
@property (nonatomic, strong) UIView *contentHost;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@property (nonatomic, strong) UIView *overviewPanel;
@property (nonatomic, strong) UIView *runtimePanel;
@property (nonatomic, strong) UIView *adminIpPanel;
@property (nonatomic, strong) UIView *whitePanel;
@property (nonatomic, strong) UIView *blackPanel;
@property (nonatomic, strong) UIView *certPanel;

@property (nonatomic, strong) UISwitch *adminIpSwitch;
@property (nonatomic, strong) UISwitch *discoverSwitch;
@property (nonatomic, strong) UITextField *clearTokenField;
@property (nonatomic, strong) UILabel *clearTokenHint;
@property (nonatomic, strong) UILabel *overviewInfo;

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
@property (nonatomic, strong) UIView *shieldPanel;
@property (nonatomic, strong) UIView *jumpPanel;
@property (nonatomic, strong) UITextView *shieldText;
@property (nonatomic, strong) UITextView *jumpText;
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
  self.title = @"运维管理";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(_refreshAll)];

  _statusLabel = [UILabel new];
  _statusLabel.numberOfLines = 2;
  _statusLabel.font = [UIFont systemFontOfSize:13];
  _statusLabel.textColor = UIColor.secondaryLabelColor;
  _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];

  _tabScroll = [UIScrollView new];
  _tabScroll.showsHorizontalScrollIndicator = NO;
  _tabs = [[UISegmentedControl alloc] initWithItems:@[@"概览", @"运行", @"管理IP", @"白名单", @"黑名单", @"盾牌", @"跳转", @"证书"]];
  _tabs.selectedSegmentIndex = 0;
  [_tabs addTarget:self action:@selector(_tabChanged) forControlEvents:UIControlEventValueChanged];
  [_tabScroll addSubview:_tabs];

  _contentHost = [UIView new];
  [self.view addSubview:_statusLabel];
  [self.view addSubview:_spinner];
  [self.view addSubview:_tabScroll];
  [self.view addSubview:_contentHost];

  [_statusLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(self.view).offset(16);
    make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(8);
    make.right.equalTo(_spinner.mas_left).offset(-8);
  }];
  [_spinner mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(_statusLabel);
    make.right.equalTo(self.view).offset(-16);
  }];
  [_tabScroll mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.equalTo(self.view);
    make.top.equalTo(_statusLabel.mas_bottom).offset(8);
    make.height.mas_equalTo(44);
  }];
  [_tabs mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_tabScroll).insets(UIEdgeInsetsMake(4, 12, 4, 12));
    make.height.mas_equalTo(32);
    make.width.mas_greaterThanOrEqualTo(560);
  }];
  [_contentHost mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.bottom.equalTo(self.view);
    make.top.equalTo(_tabScroll.mas_bottom);
  }];

  [self _buildPanels];
  [self _tabChanged];
  [self _refreshAll];
}

#pragma mark - Busy

- (void)_beginBusy {
  self.busyDepth++;
  [self.spinner startAnimating];
}

- (void)_endBusy {
  self.busyDepth = MAX(0, self.busyDepth - 1);
  if (self.busyDepth == 0) [self.spinner stopAnimating];
}

- (void)_setStatus:(NSString *)s {
  self.statusLabel.text = s;
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
  // Overview
  _overviewPanel = [UIView new];
  _overviewInfo = [UILabel new];
  _overviewInfo.numberOfLines = 0;
  _overviewInfo.font = [UIFont systemFontOfSize:14];
  _adminIpSwitch = [UISwitch new];
  [_adminIpSwitch addTarget:self action:@selector(_toggleAdminIp) forControlEvents:UIControlEventValueChanged];
  _discoverSwitch = [UISwitch new];
  [_discoverSwitch addTarget:self action:@selector(_toggleDiscover) forControlEvents:UIControlEventValueChanged];
  _clearTokenField = [UITextField new];
  _clearTokenField.borderStyle = UITextBorderStyleRoundedRect;
  _clearTokenField.secureTextEntry = YES;
  _clearTokenField.placeholder = @"清除确认令牌";
  _clearTokenHint = [UILabel new];
  _clearTokenHint.numberOfLines = 0;
  _clearTokenHint.font = [UIFont systemFontOfSize:12];
  _clearTokenHint.textColor = UIColor.secondaryLabelColor;
  UIButton *verifyTok = [UIButton buttonWithType:UIButtonTypeSystem];
  [verifyTok setTitle:@"校验" forState:UIControlStateNormal];
  [verifyTok addTarget:self action:@selector(_verifyClearToken) forControlEvents:UIControlEventTouchUpInside];
  UIButton *saveTok = [UIButton buttonWithType:UIButtonTypeSystem];
  [saveTok setTitle:@"保存" forState:UIControlStateNormal];
  [saveTok addTarget:self action:@selector(_saveClearToken) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *tokRow = [[UIStackView alloc] initWithArrangedSubviews:@[_clearTokenField, verifyTok, saveTok]];
  tokRow.spacing = 8;
  [_clearTokenField setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  UILabel *adminL = [UILabel new]; adminL.text = @"管理 IP 门禁";
  UILabel *discL = [UILabel new]; discL.text = @"公开发现页";
  UIStackView *adminRow = [[UIStackView alloc] initWithArrangedSubviews:@[adminL, _adminIpSwitch]];
  UIStackView *discRow = [[UIStackView alloc] initWithArrangedSubviews:@[discL, _discoverSwitch]];
  UIButton *recovery = [UIButton buttonWithType:UIButtonTypeSystem];
  [recovery setTitle:@"丢钥恢复说明" forState:UIControlStateNormal];
  [recovery addTarget:self action:@selector(_openRecovery) forControlEvents:UIControlEventTouchUpInside];
  UIButton *claimIp = [UIButton buttonWithType:UIButtonTypeSystem];
  [claimIp setTitle:@"认领当前 IP 为管理 IP" forState:UIControlStateNormal];
  [claimIp addTarget:self action:@selector(_claimCurrentAdminIp) forControlEvents:UIControlEventTouchUpInside];
  UIButton *copyDiscover = [UIButton buttonWithType:UIButtonTypeSystem];
  [copyDiscover setTitle:@"复制发现链接" forState:UIControlStateNormal];
  [copyDiscover addTarget:self action:@selector(_copyDiscover) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *ov = [[UIStackView alloc] initWithArrangedSubviews:@[_overviewInfo, adminRow, discRow, tokRow, _clearTokenHint, claimIp, copyDiscover, recovery]];
  ov.axis = UILayoutConstraintAxisVertical;
  ov.spacing = 12;
  [_overviewPanel addSubview:ov];
  [ov mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_overviewPanel).insets(UIEdgeInsetsMake(16, 16, 16, 16));
  }];

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

  _shieldPanel = [UIView new];
  _shieldText = [UITextView new];
  _shieldText.editable = NO;
  _shieldText.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  UIButton *shieldRefresh = [UIButton buttonWithType:UIButtonTypeSystem];
  [shieldRefresh setTitle:@"刷新盾牌" forState:UIControlStateNormal];
  [shieldRefresh addTarget:self action:@selector(_loadShield) forControlEvents:UIControlEventTouchUpInside];
  UIButton *shieldToggle = [UIButton buttonWithType:UIButtonTypeSystem];
  [shieldToggle setTitle:@"切换总开关" forState:UIControlStateNormal];
  [shieldToggle addTarget:self action:@selector(_toggleShieldEnable) forControlEvents:UIControlEventTouchUpInside];
  UIButton *shieldAdd = [UIButton buttonWithType:UIButtonTypeSystem];
  [shieldAdd setTitle:@"添加 uri=/" forState:UIControlStateNormal];
  [shieldAdd addTarget:self action:@selector(_addDefaultShield) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *shieldTop = [[UIStackView alloc] initWithArrangedSubviews:@[shieldRefresh, shieldToggle, shieldAdd]];
  shieldTop.axis = UILayoutConstraintAxisHorizontal;
  shieldTop.spacing = 12;
  [_shieldPanel addSubview:shieldTop];
  [_shieldPanel addSubview:_shieldText];
  [shieldTop mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.left.right.equalTo(_shieldPanel).insets(UIEdgeInsetsMake(8, 16, 0, 16));
  }];
  [_shieldText mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(shieldTop.mas_bottom).offset(8);
    make.left.right.bottom.equalTo(_shieldPanel).insets(UIEdgeInsetsMake(0, 8, 8, 8));
  }];

  _jumpPanel = [UIView new];
  _jumpText = [UITextView new];
  _jumpText.editable = NO;
  _jumpText.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  UIButton *jumpRefresh = [UIButton buttonWithType:UIButtonTypeSystem];
  [jumpRefresh setTitle:@"刷新跳转" forState:UIControlStateNormal];
  [jumpRefresh addTarget:self action:@selector(_loadJump) forControlEvents:UIControlEventTouchUpInside];
  UIButton *jumpAdd = [UIButton buttonWithType:UIButtonTypeSystem];
  [jumpAdd setTitle:@"添加跳转" forState:UIControlStateNormal];
  [jumpAdd addTarget:self action:@selector(_addJump) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *jumpTop = [[UIStackView alloc] initWithArrangedSubviews:@[jumpRefresh, jumpAdd]];
  jumpTop.axis = UILayoutConstraintAxisHorizontal;
  jumpTop.spacing = 12;
  [_jumpPanel addSubview:jumpTop];
  [_jumpPanel addSubview:_jumpText];
  [jumpTop mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.left.right.equalTo(_jumpPanel).insets(UIEdgeInsetsMake(8, 16, 0, 16));
  }];
  [_jumpText mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(jumpTop.mas_bottom).offset(8);
    make.left.right.bottom.equalTo(_jumpPanel).insets(UIEdgeInsetsMake(0, 8, 8, 8));
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
  NSInteger i = self.tabs.selectedSegmentIndex;
  if (i < 0 || i >= (NSInteger)panels.count) return;
  UIView *p = panels[i];
  [self.contentHost addSubview:p];
  [p mas_makeConstraints:^(MASConstraintMaker *make) { make.edges.equalTo(self.contentHost); }];
  if (i == 1) [self _loadRuntime];
  if (i == 2) [self _loadIpKind:0];
  if (i == 3) [self _loadIpKind:1];
  if (i == 4) [self _loadIpKind:2];
  if (i == 5) [self _loadShield];
  if (i == 6) [self _loadJump];
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
      self.adminIpSwitch.on = [self.adminIpEnable boolValue];
      self.discoverSwitch.on = [self.discoverEnabled boolValue];
      if (![self.clearTokenConfigured boolValue]) {
        self.clearTokenStatus = AutumnOpsClearTokenUIServerUnset;
        self.clearTokenHint.text = @"尚未配置：填写新令牌后点「保存」";
      } else if (self.clearTokenStatus == AutumnOpsClearTokenUIServerUnset) {
        self.clearTokenStatus = AutumnOpsClearTokenUIEmpty;
        self.clearTokenHint.text = @"已配置：校验通过后才可做敏感操作";
      }
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
    NSInteger active = [data[@"activeCount"] respondsToSelector:@selector(integerValue)] ? [data[@"activeCount"] integerValue] : maps.count;
    AutumnOpsCredentialBundle *b = [self.client currentBundle:nil];
    self.overviewInfo.text = [NSString stringWithFormat:
                              @"站点：%@\n本机访问 IP：%@%@%@\n本机证书：%@\n有效证书数：%ld",
                              self.client.baseUrl,
                              self.currentIp.length ? self.currentIp : @"未知",
                              self.currentIpInAdmin ? @"（已在管理IP）" : @"",
                              self.currentIpInWhite ? @"（已在白名单）" : @"",
                              b.certId ?: @"-",
                              (long)active];
    [self _setStatus:[NSString stringWithFormat:@"已同步 · 本机访问 IP：%@", self.currentIp.length ? self.currentIp : @"未知"]];
    [self.certTable reloadData];
    NSInteger tab = self.tabs.selectedSegmentIndex;
    if (tab == 2) [self _loadIpKind:0];
    if (tab == 3) [self _loadIpKind:1];
    if (tab == 4) [self _loadIpKind:2];
    if (tab == 5) [self _loadShield];
    if (tab == 6) [self _loadJump];
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

- (NSString *)_readyClearTokenOrNil {
  NSString *t = [self.clearTokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (self.clearTokenStatus == AutumnOpsClearTokenUIReady && self.verifiedClearToken.length && [t isEqualToString:self.verifiedClearToken]) {
    return t;
  }
  return nil;
}

- (void)_toggleAdminIp {
  BOOL on = self.adminIpSwitch.on;
  if (self.adminIpEnable.boolValue && !on) {
    if (self.clearTokenConfigured != nil && !self.clearTokenConfigured.boolValue) {
      self.adminIpSwitch.on = YES;
      [self _toast:@"请先配置清除确认令牌"];
      return;
    }
    NSString *tok = [self _readyClearTokenOrNil];
    if (!tok.length) {
      self.adminIpSwitch.on = YES;
      [self _toast:@"关闭管理 IP 门禁需先在概览校验清除确认令牌"];
      return;
    }
    [self _confirm:@"关闭管理 IP 门禁" body:@"关闭后未列入管理 IP 的访问将无法进入运维。确认关闭？" ok:^{
      [self _applyAdminIpEnable:NO clearToken:tok];
    }];
    self.adminIpSwitch.on = YES; // wait confirm
    return;
  }
  [self _applyAdminIpEnable:on clearToken:[self _readyClearTokenOrNil]];
}

- (void)_applyAdminIpEnable:(BOOL)on clearToken:(NSString *)tok {
  [self _beginBusy];
  [self.client gateSetAdminIpEnable:on clearToken:tok completion:^(NSDictionary *data, NSError *error) {
    [self _endBusy];
    if (error) {
      self.adminIpSwitch.on = !on;
      [self _toast:error.localizedDescription];
      return;
    }
    self.adminIpEnable = @(on);
    self.adminIpSwitch.on = on;
    [self _refreshAll];
  }];
}

- (void)_toggleDiscover {
  BOOL on = self.discoverSwitch.on;
  if (!on) {
    [self _confirm:@"关闭公开发现页" body:@"关闭后浏览器访问 /ops/discover 将 404；App 探测仍可用。确认关闭？" ok:^{
      [self _applyDiscover:NO];
    }];
    self.discoverSwitch.on = YES;
    return;
  }
  [self _applyDiscover:YES];
}

- (void)_applyDiscover:(BOOL)on {
  [self _beginBusy];
  [self.client gateSetDiscoverEnabled:on completion:^(NSDictionary *data, NSError *error) {
    [self _endBusy];
    if (error) {
      self.discoverSwitch.on = !on;
      [self _toast:error.localizedDescription];
      return;
    }
    self.discoverEnabled = @(on);
    self.discoverSwitch.on = on;
  }];
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

- (void)_loadShield {
  [self _beginBusy];
  [self.client shieldStatus:^(NSDictionary *status, NSError *e1) {
    if (e1) {
      [self _endBusy];
      self.shieldText.text = e1.localizedDescription;
      return;
    }
    [self.client shieldListPage:1 limit:100 completion:^(NSDictionary *page, NSError *e2) {
      [self _endBusy];
      if (e2) {
        self.shieldText.text = e2.localizedDescription;
        return;
      }
      NSMutableString *s = [NSMutableString stringWithFormat:@"status attack=%@ print=%@ enable=%@\n\n",
                            status[@"attack"], status[@"print"], status[@"enable"]];
      NSArray *list = [page[@"list"] isKindOfClass:[NSArray class]] ? page[@"list"] : @[];
      for (id o in list) {
        if (![o isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *r = o;
        [s appendFormat:@"#%@ %@ enable=%@ auto=%@\n", r[@"id"], r[@"uri"], r[@"enable"], r[@"auto"]];
      }
      self.shieldText.text = s;
    }];
  }];
}

- (void)_toggleShieldEnable {
  [self _beginBusy];
  [self.client shieldStatus:^(NSDictionary *status, NSError *error) {
    if (error) {
      [self _endBusy];
      [self _toast:error.localizedDescription];
      return;
    }
    BOOL next = ![status[@"enable"] boolValue];
    [self.client shieldSetEnable:next completion:^(NSDictionary *data, NSError *e2) {
      [self _endBusy];
      if (e2) [self _toast:e2.localizedDescription];
      else [self _loadShield];
    }];
  }];
}

- (void)_addDefaultShield {
  [self _beginBusy];
  [self.client shieldSaveUri:@"/" enable:YES autoValue:10000 completion:^(NSDictionary *data, NSError *error) {
    [self _endBusy];
    if (error) [self _toast:error.localizedDescription];
    else [self _loadShield];
  }];
}

- (void)_loadJump {
  [self _beginBusy];
  [self.client jumpListPage:1 limit:100 completion:^(NSDictionary *page, NSError *error) {
    [self _endBusy];
    if (error) {
      self.jumpText.text = error.localizedDescription;
      return;
    }
    NSMutableString *s = [NSMutableString string];
    NSArray *list = [page[@"list"] isKindOfClass:[NSArray class]] ? page[@"list"] : @[];
    for (id o in list) {
      if (![o isKindOfClass:[NSDictionary class]]) continue;
      NSDictionary *r = o;
      [s appendFormat:@"#%@ %@%@ → %@ enable=%@\n", r[@"id"], r[@"host"], r[@"uri"], r[@"url"], r[@"enable"]];
    }
    if (!s.length) [s appendString:@"暂无跳转规则"];
    self.jumpText.text = s;
  }];
}

- (void)_addJump {
  UIAlertController *a = [UIAlertController alertControllerWithTitle:@"添加跳转" message:nil preferredStyle:UIAlertControllerStyleAlert];
  [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"host"; }];
  [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"uri"; tf.text = @"/"; }];
  [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"url"; }];
  [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *host = [a.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *uri = [a.textFields[1].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *url = [a.textFields[2].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!host.length || !uri.length || !url.length) {
      [self _toast:@"host、uri、url 均不能为空"];
      return;
    }
    [self _beginBusy];
    [self.client jumpSaveHost:host uri:uri url:url enable:YES completion:^(NSDictionary *data, NSError *error) {
      [self _endBusy];
      if (error) [self _toast:error.localizedDescription];
      else [self _loadJump];
    }];
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
