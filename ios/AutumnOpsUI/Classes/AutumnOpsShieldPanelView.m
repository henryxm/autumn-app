#import "AutumnOpsShieldPanelView.h"
#import "AutumnOpsConfirmPresenter.h"
#import "AutumnOpsCountChipBarView.h"
#import "AutumnOpsFusedDualFieldActionView.h"
#import "AutumnOpsKeyboardDismissHelper.h"
#import "AutumnOpsRuleRowChromeView.h"
#import "AutumnOpsSectionCardView.h"
#import "AutumnOpsSwitchRowView.h"
#import "AutumnOpsUIControls.h"
#import "AutumnOpsUITheme.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>
#import <objc/runtime.h>

static const NSInteger kShieldLimit = 50;
static const void *kShieldRowIdKey = &kShieldRowIdKey;
static const void *kShieldEnableKey = &kShieldEnableKey;
static const void *kShieldUriKey = &kShieldUriKey;

@interface AutumnOpsShieldPanelView ()
@property (nonatomic, strong) AutumnOpsClient *client;
@property (nonatomic, copy) AutumnOpsPanelToast toast;
@property (nonatomic, copy) AutumnOpsPanelBusy setBusy;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *rootStack;
@property (nonatomic, strong) AutumnOpsSectionCardView *settingsCard;
@property (nonatomic, strong) AutumnOpsSwitchRowView *enableRow;
@property (nonatomic, strong) AutumnOpsSwitchRowView *attackRow;
@property (nonatomic, strong) AutumnOpsSwitchRowView *printRow;
@property (nonatomic, strong) AutumnOpsFusedDualFieldActionView *addDual;
@property (nonatomic, strong) AutumnOpsCountChipBarView *countBar;
@property (nonatomic, strong) UIStackView *rowsStack;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingSpin;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *rows;
@property (nonatomic) NSInteger page;
@property (nonatomic) NSInteger totalCount;
@property (nonatomic) BOOL hasMore;
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL loadingMore;
@end

@implementation AutumnOpsShieldPanelView

- (instancetype)initWithClient:(AutumnOpsClient *)client
                         toast:(AutumnOpsPanelToast)toast
                       setBusy:(AutumnOpsPanelBusy)setBusy {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _client = client;
    _toast = [toast copy];
    _setBusy = [setBusy copy];
    _rows = [NSMutableArray array];
    [self _build];
  }
  return self;
}

- (void)_build {
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
  title.text = @"攻击防御";
  title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
  title.textColor = AutumnOpsUITheme.onSurface;
  UILabel *desc = [UILabel new];
  desc.text = @"配置需防护的资源路径；总开关写库生效，攻击模式与打印为运行时开关。";
  desc.numberOfLines = 0;
  desc.font = [UIFont systemFontOfSize:13];
  desc.textColor = AutumnOpsUITheme.onSurfaceVariant;
  [_rootStack addArrangedSubview:title];
  [_rootStack addArrangedSubview:desc];

  _settingsCard = [[AutumnOpsSectionCardView alloc] initWithTitle:@"运行开关"
                                                             body:@"总开关写入数据库；攻击模式与打印仅影响当前进程内存。"];
  _enableRow = [[AutumnOpsSwitchRowView alloc] initWithTitle:@"总开关" subtitle:@"启用或关闭默认盾牌规则集"];
  _attackRow = [[AutumnOpsSwitchRowView alloc] initWithTitle:@"攻击模式" subtitle:@"对未放行 IP 拦截匹配资源"];
  _printRow = [[AutumnOpsSwitchRowView alloc] initWithTitle:@"打印日志" subtitle:@"拦截与放行时输出防护日志"];
  [_enableRow.switchControl addTarget:self action:@selector(_enableChanged) forControlEvents:UIControlEventValueChanged];
  [_attackRow.switchControl addTarget:self action:@selector(_attackChanged) forControlEvents:UIControlEventValueChanged];
  [_printRow.switchControl addTarget:self action:@selector(_printChanged) forControlEvents:UIControlEventValueChanged];
  [_settingsCard.contentStack addArrangedSubview:_enableRow];
  [_settingsCard.contentStack addArrangedSubview:_attackRow];
  [_settingsCard.contentStack addArrangedSubview:_printRow];
  [_rootStack addArrangedSubview:_settingsCard];

  _addDual = [[AutumnOpsFusedDualFieldActionView alloc] initWithPrimaryHint:@"资源路径，如 /"
                                                             secondaryHint:@"自动阈值"
                                                               actionTitle:@"添加"
                                                                    target:self
                                                                    action:@selector(_addRule)];
  _addDual.primaryField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  _addDual.primaryField.autocorrectionType = UITextAutocorrectionTypeNo;
  _addDual.secondaryField.text = @"10000";
  _addDual.secondaryField.keyboardType = UIKeyboardTypeNumberPad;
  [_rootStack addArrangedSubview:_addDual];

  _countBar = [AutumnOpsCountChipBarView new];
  __weak typeof(self) weakSelf = self;
  _countBar.onLoadMore = ^{ [weakSelf _loadMore]; };
  [_rootStack addArrangedSubview:_countBar];

  _loadingSpin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  _loadingSpin.hidesWhenStopped = YES;
  [_rootStack addArrangedSubview:_loadingSpin];

  _errorLabel = [UILabel new];
  _errorLabel.numberOfLines = 0;
  _errorLabel.font = [UIFont systemFontOfSize:13];
  _errorLabel.textColor = AutumnOpsUITheme.error;
  _errorLabel.hidden = YES;
  _errorLabel.textAlignment = NSTextAlignmentCenter;
  [_rootStack addArrangedSubview:_errorLabel];

  UIButton *retry = [AutumnOpsUIControls buttonWithTitle:@"重试"
                                                   style:AutumnOpsButtonStyleOutlined
                                                  target:self
                                                  action:@selector(reload)];
  retry.tag = 801;
  retry.hidden = YES;
  [_rootStack addArrangedSubview:retry];

  _emptyLabel = [UILabel new];
  _emptyLabel.text = @"暂无规则，在上方填写路径后添加";
  _emptyLabel.font = [UIFont systemFontOfSize:14];
  _emptyLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;
  _emptyLabel.textAlignment = NSTextAlignmentCenter;
  _emptyLabel.hidden = YES;
  [_rootStack addArrangedSubview:_emptyLabel];

  _rowsStack = [UIStackView new];
  _rowsStack.axis = UILayoutConstraintAxisVertical;
  _rowsStack.spacing = 0;
  [_rootStack addArrangedSubview:_rowsStack];
}

- (UIViewController *)_hostVC {
  UIResponder *r = self;
  while (r) {
    if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r;
    r = r.nextResponder;
  }
  return nil;
}

- (BOOL)_pageHasMore:(NSDictionary *)page pageNum:(NSInteger)pageNum {
  if (page[@"hasMore"] != nil) return [page[@"hasMore"] boolValue];
  NSInteger count = [page[@"count"] respondsToSelector:@selector(integerValue)] ? [page[@"count"] integerValue] : 0;
  return pageNum * kShieldLimit < count;
}

- (void)reload {
  if (self.loading) return;
  self.loading = YES;
  self.errorLabel.hidden = YES;
  [self viewWithTag:801].hidden = YES;
  if (self.rows.count == 0) [self.loadingSpin startAnimating];
  if (self.setBusy) self.setBusy(YES);
  __weak typeof(self) weakSelf = self;
  [self.client ensureSession:^(NSError *sessErr) {
    if (sessErr) {
      [weakSelf _reloadFailed:sessErr.localizedDescription];
      return;
    }
    [weakSelf.client shieldStatus:^(NSDictionary *status, NSError *e1) {
      if (e1) {
        [weakSelf _reloadFailed:e1.localizedDescription];
        return;
      }
      weakSelf.enableRow.switchControl.on = [status[@"enable"] boolValue];
      weakSelf.attackRow.switchControl.on = [status[@"attack"] boolValue];
      weakSelf.printRow.switchControl.on = [status[@"print"] boolValue];
      [weakSelf.client shieldListPage:1 limit:kShieldLimit completion:^(NSDictionary *page, NSError *e2) {
        [weakSelf _finishReloadPage:page error:e2];
      }];
    }];
  }];
}

- (void)_reloadFailed:(NSString *)msg {
  self.loading = NO;
  if (self.setBusy) self.setBusy(NO);
  [self.loadingSpin stopAnimating];
  if (self.scroll.refreshControl.refreshing) [self.scroll.refreshControl endRefreshing];
  self.errorLabel.text = [NSString stringWithFormat:@"加载失败：%@", msg ?: @"未知错误"];
  self.errorLabel.hidden = self.rows.count > 0;
  [self viewWithTag:801].hidden = self.rows.count > 0;
  if (self.toast && self.rows.count > 0) self.toast(msg);
  [self _refreshCountBar];
}

- (void)_finishReloadPage:(NSDictionary *)page error:(NSError *)error {
  self.loading = NO;
  if (self.setBusy) self.setBusy(NO);
  [self.loadingSpin stopAnimating];
  if (self.scroll.refreshControl.refreshing) [self.scroll.refreshControl endRefreshing];
  if (error) {
    [self _reloadFailed:error.localizedDescription];
    return;
  }
  NSArray *list = [page[@"list"] isKindOfClass:[NSArray class]] ? page[@"list"] : @[];
  [self.rows removeAllObjects];
  for (id o in list) if ([o isKindOfClass:[NSDictionary class]]) [self.rows addObject:o];
  self.page = [page[@"page"] respondsToSelector:@selector(integerValue)] ? [page[@"page"] integerValue] : 1;
  if (self.page <= 0) self.page = 1;
  self.totalCount = [page[@"count"] respondsToSelector:@selector(integerValue)] ? [page[@"count"] integerValue] : self.rows.count;
  self.hasMore = [self _pageHasMore:page pageNum:self.page];
  self.errorLabel.hidden = YES;
  [self viewWithTag:801].hidden = YES;
  [self _rebuildRows];
}

- (void)_loadMore {
  if (self.loading || self.loadingMore || !self.hasMore) return;
  self.loadingMore = YES;
  [self _refreshCountBar];
  NSInteger next = self.page + 1;
  __weak typeof(self) weakSelf = self;
  [self.client shieldListPage:next limit:kShieldLimit completion:^(NSDictionary *page, NSError *error) {
    weakSelf.loadingMore = NO;
    if (error) {
      if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
      [weakSelf _refreshCountBar];
      return;
    }
    NSArray *list = [page[@"list"] isKindOfClass:[NSArray class]] ? page[@"list"] : @[];
    for (id o in list) if ([o isKindOfClass:[NSDictionary class]]) [weakSelf.rows addObject:o];
    weakSelf.page = [page[@"page"] respondsToSelector:@selector(integerValue)] ? [page[@"page"] integerValue] : next;
    weakSelf.totalCount = [page[@"count"] respondsToSelector:@selector(integerValue)] ? [page[@"count"] integerValue] : weakSelf.totalCount;
    weakSelf.hasMore = [weakSelf _pageHasMore:page pageNum:weakSelf.page];
    [weakSelf _rebuildRows];
  }];
}

- (void)_refreshCountBar {
  [self.countBar configureLoaded:self.rows.count
                           total:self.totalCount
                         hasMore:self.hasMore && !self.loading
                     loadingMore:self.loadingMore
                      emptyLabel:@"暂无规则"];
}

- (void)_rebuildRows {
  for (UIView *v in [self.rowsStack.arrangedSubviews copy]) {
    [self.rowsStack removeArrangedSubview:v];
    [v removeFromSuperview];
  }
  [self _refreshCountBar];
  self.emptyLabel.hidden = self.rows.count > 0 || self.loading;
  for (NSDictionary *row in self.rows) {
    BOOL on = [row[@"enable"] boolValue];
    NSString *uri = [NSString stringWithFormat:@"%@", row[@"uri"] ?: @""];
    NSString *autoS = [NSString stringWithFormat:@"%@", row[@"auto"] ?: @"0"];
    AutumnOpsRuleRowChromeView *chrome =
        [[AutumnOpsRuleRowChromeView alloc] initWithTitle:uri
                                                 subtitle:[NSString stringWithFormat:@"自动阈值 · %@", autoS]
                                                   active:on
                                              statusLabel:on ? @"已开启" : @"已关闭"
                                           titleMonospace:YES];
    UIButton *toggle = [AutumnOpsRuleRowChromeView textAction:on ? @"关闭" : @"开启" target:self action:@selector(_toggle:)];
    UIButton *del = [AutumnOpsRuleRowChromeView destructiveTextAction:@"删除" target:self action:@selector(_delete:)];
    NSNumber *sid = @([row[@"id"] integerValue]);
    objc_setAssociatedObject(toggle, kShieldRowIdKey, sid, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(del, kShieldRowIdKey, sid, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(toggle, kShieldEnableKey, @(on), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(toggle, kShieldUriKey, uri, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(del, kShieldUriKey, uri, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [chrome setActionViews:@[ toggle, del ]];
    [self.rowsStack addArrangedSubview:chrome];
  }
}

- (void)_enableChanged {
  BOOL v = self.enableRow.switchControl.on;
  if (self.setBusy) self.setBusy(YES);
  __weak typeof(self) weakSelf = self;
  [self.client shieldSetEnable:v completion:^(NSDictionary *data, NSError *error) {
    if (weakSelf.setBusy) weakSelf.setBusy(NO);
    if (error) {
      weakSelf.enableRow.switchControl.on = !v;
      if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
    }
  }];
}

- (void)_attackChanged {
  BOOL v = self.attackRow.switchControl.on;
  if (self.setBusy) self.setBusy(YES);
  __weak typeof(self) weakSelf = self;
  [self.client shieldSetAttack:v completion:^(NSDictionary *data, NSError *error) {
    if (weakSelf.setBusy) weakSelf.setBusy(NO);
    if (error) {
      weakSelf.attackRow.switchControl.on = !v;
      if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
    }
  }];
}

- (void)_printChanged {
  BOOL v = self.printRow.switchControl.on;
  if (self.setBusy) self.setBusy(YES);
  __weak typeof(self) weakSelf = self;
  [self.client shieldSetPrint:v completion:^(NSDictionary *data, NSError *error) {
    if (weakSelf.setBusy) weakSelf.setBusy(NO);
    if (error) {
      weakSelf.printRow.switchControl.on = !v;
      if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
    }
  }];
}

- (void)_addRule {
  NSString *uri = [self.addDual.primaryField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSInteger autoV = self.addDual.secondaryField.text.integerValue;
  if (!uri.length) {
    if (self.toast) self.toast(@"请填写资源路径，例如 / 或 /api");
    return;
  }
  if (autoV < 1000) {
    if (self.toast) self.toast(@"自动阈值须不小于 1000");
    return;
  }
  if (self.setBusy) self.setBusy(YES);
  __weak typeof(self) weakSelf = self;
  [self.client shieldSaveUri:uri enable:YES autoValue:autoV completion:^(NSDictionary *data, NSError *error) {
    if (weakSelf.setBusy) weakSelf.setBusy(NO);
    if (error) {
      if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
      return;
    }
    weakSelf.addDual.primaryField.text = @"";
    if (weakSelf.toast) weakSelf.toast([NSString stringWithFormat:@"已添加：%@", uri]);
    [weakSelf reload];
  }];
}

- (void)_toggle:(UIButton *)sender {
  NSNumber *sid = objc_getAssociatedObject(sender, kShieldRowIdKey);
  BOOL on = [objc_getAssociatedObject(sender, kShieldEnableKey) boolValue];
  NSString *uri = objc_getAssociatedObject(sender, kShieldUriKey) ?: @"";
  if (self.setBusy) self.setBusy(YES);
  __weak typeof(self) weakSelf = self;
  [self.client shieldUpdateId:sid.integerValue uri:nil enable:@(!on) autoValue:nil completion:^(NSDictionary *data, NSError *error) {
    if (weakSelf.setBusy) weakSelf.setBusy(NO);
    if (error) {
      if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
      return;
    }
    if (weakSelf.toast) weakSelf.toast(on ? [NSString stringWithFormat:@"已关闭：%@", uri] : [NSString stringWithFormat:@"已开启：%@", uri]);
    [weakSelf reload];
  }];
}

- (void)_delete:(UIButton *)sender {
  NSNumber *sid = objc_getAssociatedObject(sender, kShieldRowIdKey);
  NSString *uri = objc_getAssociatedObject(sender, kShieldUriKey) ?: @"";
  UIViewController *host = [self _hostVC];
  if (!host) return;
  __weak typeof(self) weakSelf = self;
  [AutumnOpsConfirmPresenter presentFrom:host
                                   title:@"删除规则"
                                    body:[NSString stringWithFormat:@"确定删除 %@？", uri]
                             destructive:YES
                               onConfirm:^{
    if (weakSelf.setBusy) weakSelf.setBusy(YES);
    [weakSelf.client shieldDeleteIds:@[ sid ] completion:^(NSDictionary *data, NSError *error) {
      if (weakSelf.setBusy) weakSelf.setBusy(NO);
      if (error) {
        if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
        return;
      }
      if (weakSelf.toast) weakSelf.toast([NSString stringWithFormat:@"已删除：%@", uri]);
      [weakSelf reload];
    }];
  }];
}

@end
