#import "AutumnOpsJumpPanelView.h"
#import "AutumnOpsCountChipBarView.h"
#import "AutumnOpsConfirmPresenter.h"
#import "AutumnOpsJumpEditorController.h"
#import "AutumnOpsKeyboardDismissHelper.h"
#import "AutumnOpsRuleRowChromeView.h"
#import "AutumnOpsUIControls.h"
#import "AutumnOpsUITheme.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>
#import <objc/runtime.h>

static const NSInteger kJumpLimit = 50;
static const void *kJumpRowIdKey = &kJumpRowIdKey;
static const void *kJumpRowDictKey = &kJumpRowDictKey;

@interface AutumnOpsJumpPanelView ()
@property (nonatomic, strong) AutumnOpsClient *client;
@property (nonatomic, copy) AutumnOpsPanelToast toast;
@property (nonatomic, copy) AutumnOpsPanelBusy setBusy;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *rootStack;
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

@implementation AutumnOpsJumpPanelView

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

- (UIViewController *)_hostVC {
  UIResponder *r = self;
  while (r) {
    if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r;
    r = r.nextResponder;
  }
  return nil;
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
  title.text = @"防御跳转";
  title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
  title.textColor = AutumnOpsUITheme.onSurface;
  UILabel *desc = [UILabel new];
  desc.text = @"按域名与资源匹配后跳转到目标地址，与盾牌分表互不影响。";
  desc.numberOfLines = 0;
  desc.font = [UIFont systemFontOfSize:13];
  desc.textColor = AutumnOpsUITheme.onSurfaceVariant;
  UIStackView *headerLeft = [[UIStackView alloc] initWithArrangedSubviews:@[ title, desc ]];
  headerLeft.axis = UILayoutConstraintAxisVertical;
  headerLeft.spacing = 4;
  UIButton *add = [AutumnOpsUIControls buttonWithTitle:@"添加"
                                                 style:AutumnOpsButtonStyleTonal
                                                target:self
                                                action:@selector(_add)];
  UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[ headerLeft, add ]];
  header.axis = UILayoutConstraintAxisHorizontal;
  header.alignment = UIStackViewAlignmentTop;
  header.spacing = 8;
  [headerLeft setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [_rootStack addArrangedSubview:header];

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
  _errorLabel.textAlignment = NSTextAlignmentCenter;
  _errorLabel.hidden = YES;
  [_rootStack addArrangedSubview:_errorLabel];

  UIButton *retry = [AutumnOpsUIControls buttonWithTitle:@"重试"
                                                   style:AutumnOpsButtonStyleOutlined
                                                  target:self
                                                  action:@selector(reload)];
  retry.tag = 802;
  retry.hidden = YES;
  [_rootStack addArrangedSubview:retry];

  _emptyLabel = [UILabel new];
  _emptyLabel.text = @"暂无跳转规则，点右上角添加";
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

- (BOOL)_pageHasMore:(NSDictionary *)page pageNum:(NSInteger)pageNum {
  if (page[@"hasMore"] != nil) return [page[@"hasMore"] boolValue];
  NSInteger count = [page[@"count"] respondsToSelector:@selector(integerValue)] ? [page[@"count"] integerValue] : 0;
  return pageNum * kJumpLimit < count;
}

- (void)reload {
  if (self.loading) return;
  self.loading = YES;
  self.errorLabel.hidden = YES;
  [self viewWithTag:802].hidden = YES;
  if (self.rows.count == 0) [self.loadingSpin startAnimating];
  if (self.setBusy) self.setBusy(YES);
  __weak typeof(self) weakSelf = self;
  [self.client ensureSession:^(NSError *sessErr) {
    if (sessErr) {
      [weakSelf _reloadFailed:sessErr.localizedDescription];
      return;
    }
    [weakSelf.client jumpListPage:1 limit:kJumpLimit completion:^(NSDictionary *page, NSError *error) {
      [weakSelf _finishReloadPage:page error:error];
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
  [self viewWithTag:802].hidden = self.rows.count > 0;
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
  [self viewWithTag:802].hidden = YES;
  [self _rebuildRows];
}

- (void)_loadMore {
  if (self.loading || self.loadingMore || !self.hasMore) return;
  self.loadingMore = YES;
  [self _refreshCountBar];
  NSInteger next = self.page + 1;
  __weak typeof(self) weakSelf = self;
  [self.client jumpListPage:next limit:kJumpLimit completion:^(NSDictionary *page, NSError *error) {
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
    NSString *host = [NSString stringWithFormat:@"%@", row[@"host"] ?: @""];
    NSString *uri = [NSString stringWithFormat:@"%@", row[@"uri"] ?: @""];
    NSString *url = [NSString stringWithFormat:@"%@", row[@"url"] ?: @""];
    AutumnOpsRuleRowChromeView *chrome =
        [[AutumnOpsRuleRowChromeView alloc] initWithTitle:[NSString stringWithFormat:@"%@%@", host, uri]
                                                 subtitle:[NSString stringWithFormat:@"→ %@", url]
                                                   active:on
                                              statusLabel:on ? @"已开启" : @"已关闭"
                                           titleMonospace:YES];
    UIButton *edit = [AutumnOpsRuleRowChromeView textAction:@"编辑" target:self action:@selector(_editTap:)];
    UIButton *toggle = [AutumnOpsRuleRowChromeView textAction:on ? @"关闭" : @"开启" target:self action:@selector(_toggle:)];
    UIButton *del = [AutumnOpsRuleRowChromeView destructiveTextAction:@"删除" target:self action:@selector(_delete:)];
    objc_setAssociatedObject(edit, kJumpRowDictKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(toggle, kJumpRowDictKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(del, kJumpRowDictKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [chrome setActionViews:@[ edit, toggle, del ]];
    [self.rowsStack addArrangedSubview:chrome];
  }
}

- (void)_add {
  [self _edit:nil];
}

- (void)_editTap:(UIButton *)sender {
  NSDictionary *row = objc_getAssociatedObject(sender, kJumpRowDictKey);
  [self _edit:row];
}

- (void)_edit:(NSDictionary *)existing {
  UIViewController *host = [self _hostVC];
  if (!host) return;
  BOOL isEdit = existing != nil;
  NSString *eh = existing[@"host"] ? [NSString stringWithFormat:@"%@", existing[@"host"]] : nil;
  NSString *eu = existing[@"uri"] ? [NSString stringWithFormat:@"%@", existing[@"uri"]] : @"/";
  NSString *eurl = existing[@"url"] ? [NSString stringWithFormat:@"%@", existing[@"url"]] : nil;
  BOOL enable = existing ? [existing[@"enable"] boolValue] : YES;
  AutumnOpsJumpEditorController *vc =
      [[AutumnOpsJumpEditorController alloc] initWithExistingHost:eh uri:eu url:eurl enable:enable isEdit:isEdit];
  __weak typeof(self) weakSelf = self;
  vc.onSave = ^(AutumnOpsJumpEditorResult *result) {
    if (!result.host.length || !result.uri.length || !result.url.length) {
      if (weakSelf.toast) weakSelf.toast(@"域名、资源路径、跳转地址均不能为空");
      return;
    }
    if (weakSelf.setBusy) weakSelf.setBusy(YES);
    void (^done)(NSDictionary *, NSError *) = ^(NSDictionary *data, NSError *error) {
      if (weakSelf.setBusy) weakSelf.setBusy(NO);
      if (error) {
        if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
        return;
      }
      if (weakSelf.toast) {
        weakSelf.toast(isEdit ? [NSString stringWithFormat:@"已更新：%@%@", result.host, result.uri]
                              : [NSString stringWithFormat:@"已添加：%@%@", result.host, result.uri]);
      }
      [weakSelf reload];
    };
    if (isEdit) {
      [weakSelf.client jumpUpdateId:[existing[@"id"] integerValue]
                               host:result.host
                                uri:result.uri
                                url:result.url
                             enable:@(result.enable)
                         completion:done];
    } else {
      [weakSelf.client jumpSaveHost:result.host uri:result.uri url:result.url enable:result.enable completion:done];
    }
  };
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
  nav.modalPresentationStyle = UIModalPresentationFormSheet;
  [host presentViewController:nav animated:YES completion:nil];
}

- (void)_toggle:(UIButton *)sender {
  NSDictionary *row = objc_getAssociatedObject(sender, kJumpRowDictKey);
  NSInteger jid = [row[@"id"] integerValue];
  BOOL next = ![row[@"enable"] boolValue];
  NSString *name = [NSString stringWithFormat:@"%@%@", row[@"host"] ?: @"", row[@"uri"] ?: @""];
  if (self.setBusy) self.setBusy(YES);
  __weak typeof(self) weakSelf = self;
  [self.client jumpUpdateId:jid host:nil uri:nil url:nil enable:@(next) completion:^(NSDictionary *data, NSError *error) {
    if (weakSelf.setBusy) weakSelf.setBusy(NO);
    if (error) {
      if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
      return;
    }
    if (weakSelf.toast) {
      weakSelf.toast(next ? [NSString stringWithFormat:@"已开启：%@", name]
                          : [NSString stringWithFormat:@"已关闭：%@", name]);
    }
    [weakSelf reload];
  }];
}

- (void)_delete:(UIButton *)sender {
  NSDictionary *row = objc_getAssociatedObject(sender, kJumpRowDictKey);
  NSInteger jid = [row[@"id"] integerValue];
  NSString *name = [NSString stringWithFormat:@"%@%@", row[@"host"] ?: @"", row[@"uri"] ?: @""];
  UIViewController *host = [self _hostVC];
  if (!host) return;
  __weak typeof(self) weakSelf = self;
  [AutumnOpsConfirmPresenter presentFrom:host
                                   title:@"删除跳转"
                                    body:[NSString stringWithFormat:@"确定删除 %@？", name]
                             destructive:YES
                               onConfirm:^{
    if (weakSelf.setBusy) weakSelf.setBusy(YES);
    [weakSelf.client jumpDeleteIds:@[ @(jid) ] completion:^(NSDictionary *data, NSError *error) {
      if (weakSelf.setBusy) weakSelf.setBusy(NO);
      if (error) {
        if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
        return;
      }
      [weakSelf reload];
    }];
  }];
}

@end
