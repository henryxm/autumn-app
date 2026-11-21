#import "AutumnOpsRuntimePanelView.h"
#import "AutumnOpsRuntimeMetricCardView.h"
#import "AutumnOpsUIControls.h"
#import "AutumnOpsUITheme.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>

@interface AutumnOpsRuntimePanelView ()
@property (nonatomic, strong) AutumnOpsClient *client;
@property (nonatomic, copy) AutumnOpsRuntimePanelToast toast;
@property (nonatomic, copy) AutumnOpsRuntimePanelBusy setBusy;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIStackView *rootStack;
@property (nonatomic, strong) UILabel *collectedLabel;
@property (nonatomic, strong) UIButton *refreshBtn;
@property (nonatomic, strong) UIActivityIndicatorView *refreshSpinner;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingSpinner;
@property (nonatomic, strong) UIStackView *cardsStack;
@property (nonatomic, strong, nullable) AutumnOpsRuntimeSnapshot *snap;
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL loadedOnce;
@end

@implementation AutumnOpsRuntimePanelView

- (instancetype)initWithClient:(AutumnOpsClient *)client
                         toast:(AutumnOpsRuntimePanelToast)toast
                       setBusy:(AutumnOpsRuntimePanelBusy)setBusy {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _client = client;
    _toast = [toast copy];
    _setBusy = [setBusy copy];
    [self _build];
  }
  return self;
}

- (void)_build {
  self.backgroundColor = UIColor.clearColor;

  _scroll = [UIScrollView new];
  _scroll.alwaysBounceVertical = YES;
  _refreshControl = [UIRefreshControl new];
  [_refreshControl addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
  _scroll.refreshControl = _refreshControl;
  [self addSubview:_scroll];
  [_scroll mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(self);
  }];

  // 对齐 Flutter ListView：padding 16、底 24；根间距 0（卡间距在 cardsStack）
  _rootStack = [UIStackView new];
  _rootStack.axis = UILayoutConstraintAxisVertical;
  _rootStack.spacing = 0;
  _rootStack.alignment = UIStackViewAlignmentFill;
  [_scroll addSubview:_rootStack];
  [_rootStack mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_scroll).insets(UIEdgeInsetsMake(16, 16, 24, 16));
    make.width.equalTo(_scroll).offset(-32);
  }];

  _collectedLabel = [UILabel new];
  _collectedLabel.font = [UIFont systemFontOfSize:12];
  _collectedLabel.numberOfLines = 2;
  _collectedLabel.text = @"下拉刷新获取运行快照";

  // 对齐 Flutter IconButton：仅小图标 16、热区 28、与卡同缘右对齐
  static const CGFloat kRefreshHit = 28;
  _refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  UIImageSymbolConfiguration *cfg =
      [UIImageSymbolConfiguration configurationWithPointSize:16
                                                      weight:UIImageSymbolWeightRegular
                                                       scale:UIImageSymbolScaleSmall];
  [_refreshBtn setImage:[UIImage systemImageNamed:@"arrow.clockwise" withConfiguration:cfg]
               forState:UIControlStateNormal];
  _refreshBtn.contentEdgeInsets = UIEdgeInsetsZero;
  _refreshBtn.accessibilityLabel = @"刷新";
  [_refreshBtn.widthAnchor constraintEqualToConstant:kRefreshHit].active = YES;
  [_refreshBtn.heightAnchor constraintEqualToConstant:kRefreshHit].active = YES;
  [_refreshBtn addTarget:self action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];

  _refreshSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  _refreshSpinner.hidesWhenStopped = YES;
  [_refreshSpinner.widthAnchor constraintEqualToConstant:14].active = YES;
  [_refreshSpinner.heightAnchor constraintEqualToConstant:14].active = YES;

  UIView *refreshHost = [UIView new];
  [refreshHost addSubview:_refreshBtn];
  [refreshHost addSubview:_refreshSpinner];
  _refreshBtn.translatesAutoresizingMaskIntoConstraints = NO;
  _refreshSpinner.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [refreshHost.widthAnchor constraintEqualToConstant:kRefreshHit],
    [refreshHost.heightAnchor constraintEqualToConstant:kRefreshHit],
    [_refreshBtn.centerXAnchor constraintEqualToAnchor:refreshHost.centerXAnchor],
    [_refreshBtn.centerYAnchor constraintEqualToAnchor:refreshHost.centerYAnchor],
    [_refreshSpinner.centerXAnchor constraintEqualToAnchor:refreshHost.centerXAnchor],
    [_refreshSpinner.centerYAnchor constraintEqualToAnchor:refreshHost.centerYAnchor],
  ]];
  [_refreshBtn setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [refreshHost setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [refreshHost setContentCompressionResistancePriority:UILayoutPriorityRequired
                                               forAxis:UILayoutConstraintAxisHorizontal];

  UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[ _collectedLabel, refreshHost ]];
  header.axis = UILayoutConstraintAxisHorizontal;
  header.alignment = UIStackViewAlignmentCenter;
  header.spacing = 8;
  header.tag = 9002;
  [_collectedLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [_collectedLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                   forAxis:UILayoutConstraintAxisHorizontal];

  _errorLabel = [UILabel new];
  _errorLabel.numberOfLines = 0;
  _errorLabel.font = [UIFont systemFontOfSize:13];
  _errorLabel.hidden = YES;

  _loadingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  _loadingSpinner.hidesWhenStopped = YES;

  UIView *loadingWrap = [UIView new];
  [loadingWrap addSubview:_loadingSpinner];
  _loadingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [_loadingSpinner.centerXAnchor constraintEqualToAnchor:loadingWrap.centerXAnchor],
    [_loadingSpinner.topAnchor constraintEqualToAnchor:loadingWrap.topAnchor constant:48],
    [_loadingSpinner.bottomAnchor constraintEqualToAnchor:loadingWrap.bottomAnchor],
    [loadingWrap.heightAnchor constraintGreaterThanOrEqualToConstant:80],
  ]];
  loadingWrap.hidden = YES;
  loadingWrap.tag = 9001;

  _cardsStack = [UIStackView new];
  _cardsStack.axis = UILayoutConstraintAxisVertical;
  _cardsStack.spacing = 12;
  _cardsStack.alignment = UIStackViewAlignmentFill;
  _cardsStack.hidden = YES;

  [_rootStack addArrangedSubview:header];
  [_rootStack addArrangedSubview:_errorLabel];
  [_rootStack addArrangedSubview:loadingWrap];
  [_rootStack addArrangedSubview:_cardsStack];
  // Flutter：header 后 error 前空 8；header→首卡无额外缝（cards 自带区隔）
  [_rootStack setCustomSpacing:8 afterView:header];
  [_rootStack setCustomSpacing:0 afterView:_errorLabel];
  [_rootStack setCustomSpacing:0 afterView:loadingWrap];
  [self _applyThemeColors];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  if (@available(iOS 13.0, *)) {
    if (![self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) return;
  }
  [self _applyThemeColors];
}

- (void)_applyThemeColors {
  self.collectedLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;
  self.refreshBtn.tintColor = AutumnOpsUITheme.primary;
  self.refreshSpinner.color = AutumnOpsUITheme.primary;
  self.errorLabel.textColor = AutumnOpsUITheme.error;
}

- (void)reload {
  [self _refresh];
}

- (void)_updateRefreshEnabled {
  self.refreshBtn.enabled = !self.loading;
  self.refreshBtn.hidden = self.loading;
  self.refreshBtn.alpha = self.loading ? 0.5 : 1.0;
}

- (void)_refresh {
  if (self.loading) return;
  self.loading = YES;
  self.errorLabel.hidden = YES;
  self.errorLabel.text = @"";
  [self _updateRefreshEnabled];
  if (self.snap == nil) {
    UIView *loadingWrap = [self.rootStack viewWithTag:9001];
    loadingWrap.hidden = NO;
    [self.loadingSpinner startAnimating];
  }
  [self.refreshSpinner startAnimating];
  if (self.setBusy) self.setBusy(YES);

  __weak typeof(self) weakSelf = self;
  [self.client runtimeSnapshotModel:^(AutumnOpsRuntimeSnapshot *snap, NSError *error) {
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) return;
    self.loading = NO;
    [self.refreshSpinner stopAnimating];
    if (self.refreshControl.refreshing) [self.refreshControl endRefreshing];
    UIView *loadingWrap = [self.rootStack viewWithTag:9001];
    loadingWrap.hidden = YES;
    [self.loadingSpinner stopAnimating];
    if (self.setBusy) self.setBusy(NO);
    self.loadedOnce = YES;
    [self _updateRefreshEnabled];

    if (error) {
      self.errorLabel.text = error.localizedDescription;
      self.errorLabel.hidden = NO;
      if (self.toast) self.toast(@"刷新运行状态失败");
      return;
    }
    self.snap = snap;
    self.errorLabel.hidden = YES;
    [self _rebuildCards];
  }];
}

#pragma mark - Cards

- (void)_rebuildCards {
  for (UIView *v in [self.cardsStack.arrangedSubviews copy]) {
    [self.cardsStack removeArrangedSubview:v];
    [v removeFromSuperview];
  }
  AutumnOpsRuntimeSnapshot *snap = self.snap;
  if (!snap) {
    self.cardsStack.hidden = YES;
    self.collectedLabel.text = @"下拉刷新获取运行快照";
    return;
  }
  self.cardsStack.hidden = NO;
  self.collectedLabel.text = [NSString stringWithFormat:@"采集于 %@", [self.class formatTime:snap.collectedAt]];

  [self.cardsStack addArrangedSubview:[self _systemCard:snap.system]];
  [self.cardsStack addArrangedSubview:[self _jvmCard:snap.jvm]];
  [self.cardsStack addArrangedSubview:[self _diskCard:snap.disk]];
  [self.cardsStack addArrangedSubview:[self _databaseCard:snap.database]];
  [self.cardsStack addArrangedSubview:[self _firewallCard:snap.firewall]];
  [self.cardsStack addArrangedSubview:[self _trafficCard:snap.traffic]];
  [self.cardsStack addArrangedSubview:[self _redisCard:snap.redis]];
  [self.cardsStack addArrangedSubview:[self _pathsCard:snap.paths]];
}

- (AutumnOpsRuntimeMetricCardView *)_naCard:(NSString *)title reason:(NSString *)reason {
  AutumnOpsRuntimeMetricCardView *card = [[AutumnOpsRuntimeMetricCardView alloc] initWithTitle:title];
  [card setNAReason:reason];
  return card;
}

- (UIView *)_kv:(NSString *)key value:(NSString *)value {
  UIView *row = [UIView new];
  UILabel *k = [UILabel new];
  k.font = [UIFont systemFontOfSize:13];
  k.textColor = AutumnOpsUITheme.onSurfaceVariant;
  k.text = key;
  k.numberOfLines = 1;

  UITextView *v = [UITextView new];
  v.editable = NO;
  v.scrollEnabled = NO;
  v.backgroundColor = UIColor.clearColor;
  v.textContainerInset = UIEdgeInsetsZero;
  v.textContainer.lineFragmentPadding = 0;
  v.font = [UIFont systemFontOfSize:13];
  v.textColor = AutumnOpsUITheme.onSurface;
  v.text = value ?: @"";

  [row addSubview:k];
  [row addSubview:v];
  k.translatesAutoresizingMaskIntoConstraints = NO;
  v.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [k.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
    [k.topAnchor constraintEqualToAnchor:row.topAnchor],
    [k.widthAnchor constraintEqualToConstant:88],
    [v.leadingAnchor constraintEqualToAnchor:k.trailingAnchor],
    [v.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
    [v.topAnchor constraintEqualToAnchor:row.topAnchor],
    [v.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-6],
  ]];
  return row;
}

- (UIView *)_bar:(double)ratio {
  UIView *wrap = [UIView new];
  UIProgressView *pv = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
  pv.progressTintColor = AutumnOpsUITheme.primary;
  pv.trackTintColor = [AutumnOpsUITheme.outlineVariant colorWithAlphaComponent:0.5];
  float p = (float)ratio;
  if (p < 0) p = 0;
  if (p > 1) p = 1;
  pv.progress = p;
  pv.layer.cornerRadius = 4;
  pv.clipsToBounds = YES;
  [wrap addSubview:pv];
  pv.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [pv.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor],
    [pv.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor],
    [pv.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:2],
    [pv.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-8],
    [pv.heightAnchor constraintEqualToConstant:8],
  ]];
  return wrap;
}

- (UIView *)_chipWrap:(NSArray<NSString *> *)labels {
  // 多行 chip 流式排布（对齐 Flutter Wrap）
  UIStackView *col = [UIStackView new];
  col.axis = UILayoutConstraintAxisVertical;
  col.spacing = 6;
  col.alignment = UIStackViewAlignmentLeading;

  UIStackView *row = [UIStackView new];
  row.axis = UILayoutConstraintAxisHorizontal;
  row.spacing = 6;
  row.alignment = UIStackViewAlignmentCenter;

  CGFloat maxW = UIScreen.mainScreen.bounds.size.width - 16 * 2 - 14 * 2 - 8;
  CGFloat used = 0;
  for (NSString *t in labels) {
    AutumnOpsChipView *chip = [AutumnOpsUIControls chipWithText:t kind:AutumnOpsChipKindEmpty compact:YES];
    CGSize sz = [chip intrinsicContentSize];
    if (used > 0 && used + 6 + sz.width > maxW) {
      [col addArrangedSubview:row];
      row = [UIStackView new];
      row.axis = UILayoutConstraintAxisHorizontal;
      row.spacing = 6;
      row.alignment = UIStackViewAlignmentCenter;
      used = 0;
    }
    [row addArrangedSubview:chip];
    used += (used > 0 ? 6 : 0) + sz.width;
  }
  if (row.arrangedSubviews.count) [col addArrangedSubview:row];

  UIView *pad = [UIView new];
  [pad addSubview:col];
  col.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [col.topAnchor constraintEqualToAnchor:pad.topAnchor constant:8],
    [col.leadingAnchor constraintEqualToAnchor:pad.leadingAnchor],
    [col.trailingAnchor constraintLessThanOrEqualToAnchor:pad.trailingAnchor],
    [col.bottomAnchor constraintEqualToAnchor:pad.bottomAnchor],
  ]];
  return pad;
}

- (UILabel *)_hint:(NSString *)text {
  UILabel *l = [UILabel new];
  l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
  l.textColor = AutumnOpsUITheme.onSurfaceVariant;
  l.text = text;
  return l;
}

- (UILabel *)_mono:(NSString *)text {
  UILabel *l = [UILabel new];
  l.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
  l.textColor = AutumnOpsUITheme.onSurface;
  l.numberOfLines = 0;
  l.text = text;
  return l;
}

#pragma mark - Section builders

- (UIView *)_systemCard:(AutumnOpsRuntimeSystem *)s {
  if (!s.available) return [self _naCard:@"系统与负载" reason:s.error];
  AutumnOpsRuntimeMetricCardView *card = [[AutumnOpsRuntimeMetricCardView alloc] initWithTitle:@"系统与负载"];
  [card.contentStack addArrangedSubview:[self _kv:@"主机" value:s.hostname.length ? s.hostname : @"暂无"]];
  NSString *os = [[NSString stringWithFormat:@"%@ %@ %@", s.osName, s.osArch, s.osVersion]
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  [card.contentStack addArrangedSubview:[self _kv:@"系统" value:os.length ? os : @"暂无"]];
  if (s.physicalTotalBytes && s.physicalTotalBytes.integerValue > 0) {
    NSInteger used = s.physicalUsedBytes.integerValue;
    NSInteger total = s.physicalTotalBytes.integerValue;
    [card.contentStack addArrangedSubview:[self _kv:@"物理内存"
                                              value:[NSString stringWithFormat:@"%@ / %@", [self.class bytes:used], [self.class bytes:total]]]];
    [card.contentStack addArrangedSubview:[self _bar:(double)used / (double)total]];
  }
  NSMutableArray *chips = [NSMutableArray array];
  [chips addObject:[NSString stringWithFormat:@"CPU %ld 核", (long)s.availableProcessors]];
  if (s.systemLoadAverage && s.systemLoadAverage.doubleValue >= 0) {
    [chips addObject:[NSString stringWithFormat:@"负载 %@", [self.class pctOrNum:s.systemLoadAverage.doubleValue]]];
  }
  if (s.processCpuLoad) {
    [chips addObject:[NSString stringWithFormat:@"进程 %@", [self.class pct:s.processCpuLoad.doubleValue]]];
  }
  if (s.systemCpuLoad) {
    [chips addObject:[NSString stringWithFormat:@"系统 %@", [self.class pct:s.systemCpuLoad.doubleValue]]];
  }
  [card.contentStack addArrangedSubview:[self _chipWrap:chips]];
  return card;
}

- (UIView *)_jvmCard:(AutumnOpsRuntimeJvm *)j {
  if (!j.available) return [self _naCard:@"JVM 内存与线程" reason:j.error];
  AutumnOpsRuntimeMetricCardView *card = [[AutumnOpsRuntimeMetricCardView alloc] initWithTitle:@"JVM 内存与线程"];
  [card.contentStack addArrangedSubview:[self _kv:@"Java" value:j.javaVersion.length ? j.javaVersion : @"暂无"]];
  [card.contentStack addArrangedSubview:[self _kv:@"运行时长" value:[self.class uptime:j.uptimeMs]]];
  if (j.heap) {
    NSInteger denom = j.heap.max > 0 ? j.heap.max : j.heap.committed;
    [card.contentStack addArrangedSubview:[self _kv:@"堆内存"
                                              value:[NSString stringWithFormat:@"%@ / %@", [self.class bytes:j.heap.used], [self.class bytes:denom]]]];
    [card.contentStack addArrangedSubview:[self _bar:j.heap.usedRatio]];
  }
  if (j.nonHeap) {
    [card.contentStack addArrangedSubview:[self _kv:@"非堆"
                                              value:[NSString stringWithFormat:@"%@ / %@", [self.class bytes:j.nonHeap.used], [self.class bytes:j.nonHeap.committed]]]];
  }
  [card.contentStack addArrangedSubview:[self _chipWrap:@[
    [NSString stringWithFormat:@"线程 %ld", (long)j.threadLive],
    [NSString stringWithFormat:@"守护 %ld", (long)j.threadDaemon],
    [NSString stringWithFormat:@"峰值 %ld", (long)j.threadPeak],
  ]]];
  return card;
}

- (UIView *)_diskCard:(AutumnOpsRuntimeDisk *)d {
  if (!d.available) return [self _naCard:@"磁盘" reason:d.error];
  if (d.volumes.count == 0) return [self _naCard:@"磁盘" reason:@"暂无卷信息"];
  AutumnOpsRuntimeMetricCardView *card = [[AutumnOpsRuntimeMetricCardView alloc] initWithTitle:@"磁盘"];
  for (AutumnOpsRuntimeDiskVolume *v in d.volumes) {
    NSString *val = v.available
        ? [NSString stringWithFormat:@"%@ / %@", [self.class bytes:v.usedBytes], [self.class bytes:v.totalBytes]]
        : (v.error.length ? v.error : @"暂无");
    [card.contentStack addArrangedSubview:[self _kv:[self.class diskLabel:v.name] value:val]];
    if (v.available) [card.contentStack addArrangedSubview:[self _bar:v.usedRatio]];
    UILabel *path = [UILabel new];
    path.font = [UIFont systemFontOfSize:11];
    path.textColor = AutumnOpsUITheme.onSurfaceVariant;
    path.numberOfLines = 0;
    path.text = v.path;
    [card.contentStack addArrangedSubview:path];
    UIView *gap = [UIView new];
    [gap.heightAnchor constraintEqualToConstant:8].active = YES;
    [card.contentStack addArrangedSubview:gap];
  }
  return card;
}

- (UIView *)_databaseCard:(AutumnOpsRuntimeDatabase *)db {
  if (!db.available) return [self _naCard:@"数据库" reason:db.error];
  AutumnOpsRuntimeMetricCardView *card = [[AutumnOpsRuntimeMetricCardView alloc] initWithTitle:@"数据库"];
  NSString *engine = [[NSString stringWithFormat:@"%@ %@", db.productName, db.productVersion]
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  [card.contentStack addArrangedSubview:[self _kv:@"引擎" value:engine.length ? engine : @"暂无"]];
  if (db.url.length) [card.contentStack addArrangedSubview:[self _kv:@"连接" value:db.url]];
  [card.contentStack addArrangedSubview:[self _kv:@"连接池" value:db.poolType.length ? db.poolType : @"暂无"]];
  if (db.maxActive) {
    NSInteger active = db.activeCount.integerValue;
    NSInteger pooling = db.poolingCount.integerValue;
    [card.contentStack addArrangedSubview:[self _kv:@"活跃连接"
                                              value:[NSString stringWithFormat:@"%ld / %@（池中 %ld）",
                                                     (long)active, db.maxActive, (long)pooling]]];
    if (db.maxActive.integerValue > 0) {
      [card.contentStack addArrangedSubview:[self _bar:(double)active / (double)db.maxActive.integerValue]];
    }
  }
  NSString *tables = @"暂无";
  if (db.tableCount) {
    if (db.tableCount.integerValue < 0) tables = db.tableCountError.length ? db.tableCountError : @"暂无";
    else tables = db.tableCount.stringValue;
  }
  [card.contentStack addArrangedSubview:[self _kv:@"表数量" value:tables]];
  return card;
}

- (UIView *)_firewallCard:(AutumnOpsRuntimeFirewall *)f {
  if (!f.available) return [self _naCard:@"防火墙与可疑 IP" reason:f.error];
  AutumnOpsRuntimeMetricCardView *card = [[AutumnOpsRuntimeMetricCardView alloc] initWithTitle:@"防火墙与可疑 IP"];
  [card.contentStack addArrangedSubview:[self _chipWrap:@[
    f.adminIpEnable ? @"管理IP开" : @"管理IP关",
    f.shieldAttack ? @"攻击模式开" : @"攻击模式关",
    [NSString stringWithFormat:@"管理 %ld", (long)f.adminIpCount],
    [NSString stringWithFormat:@"白名单 %ld", (long)f.ipWhiteCount],
    [NSString stringWithFormat:@"黑名单 %ld", (long)f.ipBlackCount],
    [NSString stringWithFormat:@"频率 %ld", (long)f.firewallCount],
    [NSString stringWithFormat:@"内存拦截 %ld", (long)f.shieldAllowedIpCount],
  ]]];
  if (f.shieldAllowedIpSample.count) {
    UIView *gap = [UIView new];
    [gap.heightAnchor constraintEqualToConstant:10].active = YES;
    [card.contentStack addArrangedSubview:gap];
    [card.contentStack addArrangedSubview:[self _hint:@"内存拦截样本"]];
    NSInteger n = MIN((NSInteger)f.shieldAllowedIpSample.count, 20);
    for (NSInteger i = 0; i < n; i++) {
      UIView *pad = [UIView new];
      UILabel *ip = [self _mono:f.shieldAllowedIpSample[i]];
      [pad addSubview:ip];
      ip.translatesAutoresizingMaskIntoConstraints = NO;
      [NSLayoutConstraint activateConstraints:@[
        [ip.topAnchor constraintEqualToAnchor:pad.topAnchor constant:4],
        [ip.leadingAnchor constraintEqualToAnchor:pad.leadingAnchor],
        [ip.trailingAnchor constraintEqualToAnchor:pad.trailingAnchor],
        [ip.bottomAnchor constraintEqualToAnchor:pad.bottomAnchor],
      ]];
      [card.contentStack addArrangedSubview:pad];
    }
  }
  if (f.blackTopToday.count) {
    UIView *gap = [UIView new];
    [gap.heightAnchor constraintEqualToConstant:10].active = YES;
    [card.contentStack addArrangedSubview:gap];
    [card.contentStack addArrangedSubview:[self _hint:@"今日黑名单命中 Top"]];
    for (AutumnOpsRuntimeBlackHit *h in f.blackTopToday) {
      UIView *row = [UIView new];
      UILabel *ip = [self _mono:h.ip];
      UILabel *today = [UILabel new];
      today.font = [UIFont systemFontOfSize:12];
      today.textColor = AutumnOpsUITheme.onSurface;
      today.text = [NSString stringWithFormat:@"今日 %ld", (long)h.today];
      [row addSubview:ip];
      [row addSubview:today];
      ip.translatesAutoresizingMaskIntoConstraints = NO;
      today.translatesAutoresizingMaskIntoConstraints = NO;
      [NSLayoutConstraint activateConstraints:@[
        [ip.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [ip.topAnchor constraintEqualToAnchor:row.topAnchor constant:4],
        [ip.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [today.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [today.centerYAnchor constraintEqualToAnchor:ip.centerYAnchor],
        [ip.trailingAnchor constraintLessThanOrEqualToAnchor:today.leadingAnchor constant:-8],
      ]];
      [card.contentStack addArrangedSubview:row];
    }
  }
  return card;
}

- (UIView *)_trafficCard:(AutumnOpsRuntimeTraffic *)t {
  if (!t.available) return [self _naCard:@"访问与吞吐" reason:t.error];
  AutumnOpsRuntimeMetricCardView *card = [[AutumnOpsRuntimeMetricCardView alloc] initWithTitle:@"访问与吞吐"];
  NSMutableArray *chips = [NSMutableArray array];
  [chips addObject:[NSString stringWithFormat:@"请求总量 %ld", (long)t.requestTotal]];
  [chips addObject:[NSString stringWithFormat:@"近 60s ≈ %.2f QPS", t.approxQps]];
  if (t.pageViewToday) [chips addObject:[NSString stringWithFormat:@"今日 PV %@", t.pageViewToday]];
  if (t.uniqueVisitorToday) [chips addObject:[NSString stringWithFormat:@"今日 UV %@", t.uniqueVisitorToday]];
  [card.contentStack addArrangedSubview:[self _chipWrap:chips]];
  if (t.visitLogError.length) {
    UIView *gap = [UIView new];
    [gap.heightAnchor constraintEqualToConstant:8].active = YES;
    [card.contentStack addArrangedSubview:gap];
    UILabel *err = [UILabel new];
    err.numberOfLines = 0;
    err.font = [UIFont systemFontOfSize:12];
    err.textColor = AutumnOpsUITheme.error;
    err.text = [NSString stringWithFormat:@"访问日志：%@", t.visitLogError];
    [card.contentStack addArrangedSubview:err];
  }
  return card;
}

- (UIView *)_redisCard:(AutumnOpsRuntimeRedis *)r {
  if (!r.enabled) return [self _naCard:@"Redis" reason:@"未启用"];
  if (!r.available) return [self _naCard:@"Redis" reason:r.error.length ? r.error : @"暂无"];
  AutumnOpsRuntimeMetricCardView *card = [[AutumnOpsRuntimeMetricCardView alloc] initWithTitle:@"Redis"];
  [card.contentStack addArrangedSubview:[self _kv:@"版本" value:r.version.length ? r.version : @"暂无"]];
  [card.contentStack addArrangedSubview:[self _kv:@"客户端" value:r.connectedClients.length ? r.connectedClients : @"暂无"]];
  NSString *mem = r.usedMemory.length ? r.usedMemory
      : (r.usedMemoryBytes ? [self.class bytes:r.usedMemoryBytes.integerValue] : @"暂无");
  [card.contentStack addArrangedSubview:[self _kv:@"内存" value:mem]];
  [card.contentStack addArrangedSubview:[self _kv:@"键数量" value:r.keyCount ? r.keyCount.stringValue : @"暂无"]];
  return card;
}

- (UIView *)_pathsCard:(AutumnOpsRuntimePaths *)p {
  if (!p.available) return [self _naCard:@"目录路径" reason:p.error];
  if (p.items.count == 0) return [self _naCard:@"目录路径" reason:@"暂无"];
  AutumnOpsRuntimeMetricCardView *card = [[AutumnOpsRuntimeMetricCardView alloc] initWithTitle:@"目录路径"];
  for (AutumnOpsRuntimePathItem *i in p.items) {
    [card.contentStack addArrangedSubview:[self _kv:i.label value:i.path.length ? i.path : @"暂无"]];
  }
  return card;
}

#pragma mark - Formatters

+ (NSString *)diskLabel:(NSString *)name {
  if ([name isEqualToString:@"workdir"]) return @"工作目录";
  if ([name isEqualToString:@"temp"]) return @"临时目录";
  if ([name isEqualToString:@"backup"]) return @"备份目录";
  return name.length ? name : @"卷";
}

+ (NSString *)formatTime:(NSInteger)ms {
  if (ms <= 0) return @"未知";
  NSDate *d = [NSDate dateWithTimeIntervalSince1970:ms / 1000.0];
  NSDateFormatter *f = [NSDateFormatter new];
  f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  f.dateFormat = @"yyyy-MM-dd HH:mm:ss";
  return [f stringFromDate:d];
}

+ (NSString *)uptime:(NSInteger)ms {
  if (ms <= 0) return @"暂无";
  NSInteger s = ms / 1000;
  NSInteger day = s / 86400;
  NSInteger h = (s % 86400) / 3600;
  NSInteger m = (s % 3600) / 60;
  if (day > 0) return [NSString stringWithFormat:@"%ld天 %ld时 %ld分", (long)day, (long)h, (long)m];
  if (h > 0) return [NSString stringWithFormat:@"%ld时 %ld分", (long)h, (long)m];
  return [NSString stringWithFormat:@"%ld分", (long)m];
}

+ (NSString *)pct:(double)v {
  return [NSString stringWithFormat:@"%.1f%%", v * 100.0];
}

+ (NSString *)pctOrNum:(double)v {
  return [NSString stringWithFormat:@"%.2f", v];
}

+ (NSString *)bytes:(NSInteger)n {
  if (n < 0) return @"暂无";
  NSArray *units = @[ @"B", @"KB", @"MB", @"GB", @"TB" ];
  double v = (double)n;
  NSInteger i = 0;
  while (v >= 1024 && i < (NSInteger)units.count - 1) {
    v /= 1024.0;
    i++;
  }
  if (v >= 100 || i == 0) return [NSString stringWithFormat:@"%.0f %@", v, units[i]];
  return [NSString stringWithFormat:@"%.1f %@", v, units[i]];
}

@end
