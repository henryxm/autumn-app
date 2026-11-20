#import "AutumnOpsIpListPanelView.h"
#import "AutumnOpsConfirmPresenter.h"
#import "AutumnOpsCountChipBarView.h"
#import "AutumnOpsFusedFieldActionView.h"
#import "AutumnOpsKeyboardDismissHelper.h"
#import "AutumnOpsMetaChipView.h"
#import "AutumnOpsRuleRowChromeView.h"
#import "AutumnOpsUIControls.h"
#import "AutumnOpsUITheme.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>
#import <objc/runtime.h>

static const NSInteger kIpLimit = 20;
static const void *kRowIpKey = &kRowIpKey;

@interface AutumnOpsIpListPanelView ()
@property (nonatomic, copy) NSString *panelTitle;
@property (nonatomic, copy) NSString *panelDescription;
@property (nonatomic) AutumnOpsIpStatusMode statusMode;
@property (nonatomic, copy) NSString *ipInputHint;
@property (nonatomic) BOOL allowClaimCurrent;
@property (nonatomic) BOOL requireClearTokenForCurrent;
@property (nonatomic) BOOL rejectPolicyBlackIp;
@property (nonatomic, copy) AutumnOpsIpPageLoader loadPage;
@property (nonatomic, copy) AutumnOpsIpAddBlock onAdd;
@property (nonatomic, copy) AutumnOpsIpRemoveBlock onRemove;
@property (nonatomic, copy) AutumnOpsIpToggleBlock onToggle;
@property (nonatomic, copy, nullable) AutumnOpsIpClearTokenResolver resolveClearToken;
@property (nonatomic, copy, nullable) void (^onMembershipMayChange)(void);
@property (nonatomic, copy) AutumnOpsIpPanelToast toast;
@property (nonatomic, copy) AutumnOpsIpPanelBusy setBusyBlock;

@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *rootStack;
@property (nonatomic, strong) AutumnOpsFusedFieldActionView *addFused;
@property (nonatomic, strong) UIButton *claimBtn;
@property (nonatomic, strong) AutumnOpsCountChipBarView *countBar;
@property (nonatomic, strong) UIStackView *rowsStack;
@property (nonatomic, strong) UILabel *errorLabel;

@property (nonatomic, strong) NSMutableArray<AutumnOpsIpRow *> *rows;
@property (nonatomic, strong) NSMutableSet<NSString *> *seenIps;
@property (nonatomic) NSInteger page;
@property (nonatomic) NSInteger totalCount;
@property (nonatomic) BOOL hasMore;
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL loadingMore;
@end

@implementation AutumnOpsIpListPanelView

- (instancetype)initWithTitle:(NSString *)title
                  description:(NSString *)description
                   statusMode:(AutumnOpsIpStatusMode)statusMode
                  ipInputHint:(NSString *)ipInputHint
            allowClaimCurrent:(BOOL)allowClaimCurrent
  requireClearTokenForCurrent:(BOOL)requireClearToken
          rejectPolicyBlackIp:(BOOL)rejectPolicyBlackIp
                       header:(UIView *)header
                     loadPage:(AutumnOpsIpPageLoader)loadPage
                        onAdd:(AutumnOpsIpAddBlock)onAdd
                     onRemove:(AutumnOpsIpRemoveBlock)onRemove
                     onToggle:(AutumnOpsIpToggleBlock)onToggle
            resolveClearToken:(AutumnOpsIpClearTokenResolver)resolveClearToken
        onMembershipMayChange:(void (^)(void))onMembershipMayChange
                        toast:(AutumnOpsIpPanelToast)toast
                      setBusy:(AutumnOpsIpPanelBusy)setBusy {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _panelTitle = [title copy];
    _panelDescription = [description copy];
    _statusMode = statusMode;
    _ipInputHint = [ipInputHint copy];
    _allowClaimCurrent = allowClaimCurrent;
    _requireClearTokenForCurrent = requireClearToken;
    _rejectPolicyBlackIp = rejectPolicyBlackIp;
    _loadPage = [loadPage copy];
    _onAdd = [onAdd copy];
    _onRemove = [onRemove copy];
    _onToggle = [onToggle copy];
    _resolveClearToken = [resolveClearToken copy];
    _onMembershipMayChange = [onMembershipMayChange copy];
    _toast = [toast copy];
    _setBusyBlock = [setBusy copy];
    _rows = [NSMutableArray array];
    _seenIps = [NSMutableSet set];
    _currentIp = @"";
    [self _buildWithHeader:header];
  }
  return self;
}

- (void)_buildWithHeader:(UIView *)header {
  self.backgroundColor = UIColor.clearColor;
  _scroll = [UIScrollView new];
  _scroll.alwaysBounceVertical = YES;
  UIRefreshControl *rc = [UIRefreshControl new];
  [rc addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
  _scroll.refreshControl = rc;
  [self addSubview:_scroll];
  [_scroll mas_makeConstraints:^(MASConstraintMaker *make) { make.edges.equalTo(self); }];
  [AutumnOpsKeyboardDismissHelper installOnScrollView:_scroll hostView:self];

  _rootStack = [UIStackView new];
  _rootStack.axis = UILayoutConstraintAxisVertical;
  _rootStack.spacing = 12;
  [_scroll addSubview:_rootStack];
  [_rootStack mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_scroll).insets(UIEdgeInsetsMake(12, 16, 28, 16));
    make.width.equalTo(_scroll).offset(-32);
  }];

  UILabel *title = [UILabel new];
  title.text = self.panelTitle;
  title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
  title.textColor = AutumnOpsUITheme.onSurface;
  UILabel *desc = [UILabel new];
  desc.text = self.panelDescription;
  desc.numberOfLines = 0;
  desc.font = [UIFont systemFontOfSize:13];
  desc.textColor = AutumnOpsUITheme.onSurfaceVariant;
  [_rootStack addArrangedSubview:title];
  [_rootStack addArrangedSubview:desc];
  if (header) [_rootStack addArrangedSubview:header];

  _addFused = [[AutumnOpsFusedFieldActionView alloc] initWithHint:self.ipInputHint
                                                      actionTitle:@"添加"
                                                           target:self
                                                           action:@selector(_addTapped)];
  _addFused.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  _addFused.textField.autocorrectionType = UITextAutocorrectionTypeNo;
  _addFused.textField.keyboardType = UIKeyboardTypeASCIICapable;
  [_rootStack addArrangedSubview:_addFused];

  _claimBtn = [AutumnOpsUIControls buttonWithTitle:@"加入当前 IP"
                                             style:AutumnOpsButtonStyleTonal
                                            target:self
                                            action:@selector(_claimTapped)];
  [_rootStack addArrangedSubview:_claimBtn];

  _countBar = [AutumnOpsCountChipBarView new];
  __weak typeof(self) weakSelf = self;
  _countBar.onLoadMore = ^{ [weakSelf _loadMore]; };
  [_rootStack addArrangedSubview:_countBar];

  _errorLabel = [UILabel new];
  _errorLabel.numberOfLines = 0;
  _errorLabel.font = [UIFont systemFontOfSize:13];
  _errorLabel.textColor = AutumnOpsUITheme.error;
  _errorLabel.hidden = YES;
  [_rootStack addArrangedSubview:_errorLabel];

  _rowsStack = [UIStackView new];
  _rowsStack.axis = UILayoutConstraintAxisVertical;
  _rowsStack.spacing = 0;
  [_rootStack addArrangedSubview:_rowsStack];

  [self _updateClaimVisibility];
}

- (void)setCurrentIp:(NSString *)currentIp {
  _currentIp = [currentIp copy] ?: @"";
  [self _rebuildRows];
}

- (void)setClaimCurrentHidden:(BOOL)claimCurrentHidden {
  _claimCurrentHidden = claimCurrentHidden;
  [self _updateClaimVisibility];
}

- (void)_updateClaimVisibility {
  self.claimBtn.hidden = !self.allowClaimCurrent || self.claimCurrentHidden || self.currentIp.length == 0;
}

- (void)reload {
  if (self.loading) return;
  self.loading = YES;
  self.page = 0;
  self.hasMore = YES;
  self.errorLabel.hidden = YES;
  if (self.setBusyBlock) self.setBusyBlock(YES);
  __weak typeof(self) weakSelf = self;
  self.loadPage(1, kIpLimit, ^(AutumnOpsIpPage *page, NSError *error) {
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) return;
    self.loading = NO;
    if (self.setBusyBlock) self.setBusyBlock(NO);
    if (self.scroll.refreshControl.refreshing) [self.scroll.refreshControl endRefreshing];
    if (error) {
      self.errorLabel.text = error.localizedDescription;
      self.errorLabel.hidden = NO;
      if (self.toast) self.toast(error.localizedDescription);
      return;
    }
    [self.rows removeAllObjects];
    [self.seenIps removeAllObjects];
    self.page = page.page > 0 ? page.page : 1;
    self.totalCount = page.count;
    self.hasMore = page.hasMore;
    for (AutumnOpsIpRow *r in page.list) {
      if (r.ip.length && ![self.seenIps containsObject:r.ip]) {
        [self.seenIps addObject:r.ip];
        [self.rows addObject:r];
      }
    }
    [self _rebuildRows];
  });
}

- (void)_loadMore {
  if (self.loading || self.loadingMore || !self.hasMore) return;
  self.loadingMore = YES;
  [self _refreshCountBar];
  NSInteger next = self.page + 1;
  __weak typeof(self) weakSelf = self;
  self.loadPage(next, kIpLimit, ^(AutumnOpsIpPage *page, NSError *error) {
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) return;
    self.loadingMore = NO;
    if (error) {
      if (self.toast) self.toast(error.localizedDescription);
      [self _refreshCountBar];
      return;
    }
    self.page = page.page > 0 ? page.page : next;
    self.totalCount = page.count;
    self.hasMore = page.hasMore;
    for (AutumnOpsIpRow *r in page.list) {
      if (r.ip.length && ![self.seenIps containsObject:r.ip]) {
        [self.seenIps addObject:r.ip];
        [self.rows addObject:r];
      }
    }
    [self _rebuildRows];
  });
}

- (BOOL)_rowActive:(AutumnOpsIpRow *)r {
  // 对齐 Flutter OpsIpRow：forbidden 默认 0；黑名单 isBlackActive = (available ?? 1) == 0
  if (self.statusMode == AutumnOpsIpStatusModeAvailable) {
    NSInteger avail = r.available != nil ? r.available.integerValue : 1;
    return avail == 0;
  }
  NSInteger forbidden = r.forbidden != nil ? r.forbidden.integerValue : 0;
  return forbidden != 1;
}

- (NSString *)_statusLabel:(AutumnOpsIpRow *)r {
  BOOL on = [self _rowActive:r];
  if (self.statusMode == AutumnOpsIpStatusModeAvailable) return on ? @"生效中" : @"已停用";
  return on ? @"启用中" : @"已禁用";
}

- (NSString *)_formatTimeMs:(NSNumber *)ms {
  if (!ms) return @"";
  long long v = llround(ms.doubleValue);
  if (v <= 0) return @"";
  // 服务端多为毫秒；若像秒级时间戳则×1000（与常见墙钟区间对齐）
  if (v < 1000000000000LL) v *= 1000LL;
  NSDateFormatter *f = [NSDateFormatter new];
  f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  f.dateFormat = @"yyyy-MM-dd HH:mm";
  return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)v / 1000.0]];
}

- (NSString *)_toggleTitle:(AutumnOpsIpRow *)r {
  BOOL on = [self _rowActive:r];
  if (!on) return @"启用";
  return self.statusMode == AutumnOpsIpStatusModeAvailable ? @"停用" : @"禁用";
}

/// 第二行说明：tag · description（日期单独第三行）。
- (NSString *)_detailForRow:(AutumnOpsIpRow *)r {
  NSMutableArray *parts = [NSMutableArray array];
  NSString *tag = [r.tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *desc = [r.descText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (tag.length) [parts addObject:tag];
  if (desc.length) [parts addObject:desc];
  return parts.count ? [parts componentsJoinedByString:@" · "] : nil;
}

- (void)_rebuildRows {
  for (UIView *v in [self.rowsStack.arrangedSubviews copy]) {
    [self.rowsStack removeArrangedSubview:v];
    [v removeFromSuperview];
  }
  [self _refreshCountBar];
  [self _updateClaimVisibility];
  for (AutumnOpsIpRow *r in self.rows) {
    BOOL active = [self _rowActive:r];
    BOOL isCurrent = self.currentIp.length && [r.ip isEqualToString:self.currentIp];
    NSString *time = [self _formatTimeMs:r.createTimeMs];
    AutumnOpsRuleRowChromeView *row =
        [[AutumnOpsRuleRowChromeView alloc] initWithTitle:r.ip
                                                 subtitle:nil
                                                   active:active
                                              statusLabel:[self _statusLabel:r]
                                           titleMonospace:YES];
    [row setDetail:[self _detailForRow:r] dateLine:time.length ? time : nil];
    [row setHighlightedBorder:isCurrent];
    if (isCurrent) {
      [row setMetaViews:@[ [[AutumnOpsMetaChipView alloc] initWithText:@"本机"] ]];
    }
    // Flutter 先前 IconButton：pause/play 在第一行右侧；delete 在说明/日期块右下
    NSString *toggleName = active ? @"pause.circle" : @"play.circle";
    NSString *toggleLabel = [self _toggleTitle:r];
    UIButton *toggle =
        [AutumnOpsRuleRowChromeView iconActionSystemName:toggleName
                                                   color:AutumnOpsUITheme.onSurfaceVariant
                                                  target:self
                                                  action:@selector(_toggle:)
                                     accessibilityLabel:toggleLabel];
    UIButton *del =
        [AutumnOpsRuleRowChromeView iconActionSystemName:@"trash"
                                                   color:[AutumnOpsUITheme.error colorWithAlphaComponent:0.85]
                                                  target:self
                                                  action:@selector(_delete:)
                                     accessibilityLabel:@"删除"];
    objc_setAssociatedObject(toggle, kRowIpKey, r.ip, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(del, kRowIpKey, r.ip, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [row setPrimaryActionView:toggle];
    [row setTrailingActionView:del];
    [self.rowsStack addArrangedSubview:row];
  }
}

- (void)_refreshCountBar {
  [self.countBar configureLoaded:self.rows.count
                           total:self.totalCount
                         hasMore:self.hasMore
                     loadingMore:self.loadingMore
                      emptyLabel:@"暂无记录"];
}

- (void)_addTapped {
  NSString *ip = [self.addFused.textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  AutumnOpsValidateResult *vr = [AutumnOpsValidators wallIp:ip rejectPolicyBlackIp:self.rejectPolicyBlackIp];
  if (!vr.ok) {
    if (self.toast) self.toast(vr.error);
    return;
  }
  [self _runAddIp:ip claim:NO];
}

- (void)_claimTapped {
  if (!self.currentIp.length) {
    if (self.toast) self.toast(@"无法获取当前访问 IP");
    return;
  }
  [self _runAddIp:nil claim:YES];
}

- (void)_runAddIp:(NSString *)ip claim:(BOOL)claim {
  if (self.setBusyBlock) self.setBusyBlock(YES);
  __weak typeof(self) weakSelf = self;
  self.onAdd(ip, claim, ^(NSString *added, NSError *error) {
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) return;
    if (self.setBusyBlock) self.setBusyBlock(NO);
    if (error) {
      if (self.toast) self.toast(error.localizedDescription);
      return;
    }
    self.addFused.textField.text = @"";
    if (self.onMembershipMayChange) self.onMembershipMayChange();
    [self reload];
  });
}

- (void)_toggle:(UIButton *)sender {
  NSString *ip = objc_getAssociatedObject(sender, kRowIpKey);
  AutumnOpsIpRow *row = nil;
  for (AutumnOpsIpRow *r in self.rows) if ([r.ip isEqualToString:ip]) { row = r; break; }
  if (!row) return;
  // 对齐 Flutter `_toggle`：动作名「停用/禁用/启用」+ 确认「确定{动作} {ip}？」+ 成功 toast
  NSString *action = [self _toggleTitle:row];
  BOOL enable = ![self _rowActive:row];
  NSString *title = [NSString stringWithFormat:@"%@ IP", action];
  NSString *body = [NSString stringWithFormat:@"确定%@ %@？", action, ip];
  UIViewController *host = [self _hostVC];
  if (!host) return;
  __weak typeof(self) weakSelf = self;
  [AutumnOpsConfirmPresenter presentFrom:host title:title body:body destructive:NO onConfirm:^{
    if (weakSelf.setBusyBlock) weakSelf.setBusyBlock(YES);
    weakSelf.onToggle(ip, enable, ^(NSError *error) {
      if (weakSelf.setBusyBlock) weakSelf.setBusyBlock(NO);
      if (error) {
        if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
        return;
      }
      if (weakSelf.toast) weakSelf.toast([NSString stringWithFormat:@"已%@：%@", action, ip]);
      [weakSelf reload];
    });
  }];
}

- (void)_delete:(UIButton *)sender {
  NSString *ip = objc_getAssociatedObject(sender, kRowIpKey);
  BOOL isCurrent = self.currentIp.length && [ip isEqualToString:self.currentIp];
  UIViewController *host = [self _hostVC];
  if (!host) return;
  __weak typeof(self) weakSelf = self;
  [AutumnOpsConfirmPresenter presentFrom:host
                                   title:@"确认删除"
                                    body:[NSString stringWithFormat:@"删除 %@？", ip]
                             destructive:YES
                               onConfirm:^{
    void (^doRemove)(NSString *) = ^(NSString *token) {
      if (weakSelf.setBusyBlock) weakSelf.setBusyBlock(YES);
      weakSelf.onRemove(ip, token, ^(NSError *error) {
        if (weakSelf.setBusyBlock) weakSelf.setBusyBlock(NO);
        if (error) {
          if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
          return;
        }
        if (weakSelf.onMembershipMayChange) weakSelf.onMembershipMayChange();
        [weakSelf reload];
      });
    };
    if (isCurrent && weakSelf.requireClearTokenForCurrent && weakSelf.resolveClearToken) {
      weakSelf.resolveClearToken(@"删除当前访问 IP 需确认清除令牌", ^(NSString *token) {
        if (!token.length) return;
        doRemove(token);
      });
    } else {
      doRemove(nil);
    }
  }];
}

- (UIViewController *)_hostVC {
  UIViewController *host = self.window.rootViewController;
  while (host.presentedViewController) host = host.presentedViewController;
  return host;
}

@end
