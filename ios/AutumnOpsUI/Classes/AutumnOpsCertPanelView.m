#import "AutumnOpsCertPanelView.h"
#import "AutumnOpsConfirmPresenter.h"
#import "AutumnOpsFusedFieldActionView.h"
#import "AutumnOpsKeyboardDismissHelper.h"
#import "AutumnOpsRecoveryViewController.h"
#import "AutumnOpsRuleRowChromeView.h"
#import "AutumnOpsSectionCardView.h"
#import "AutumnOpsShareHooks.h"
#import "AutumnOpsUIControls.h"
#import "AutumnOpsUITheme.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>

static const void *kCertIdKey = &kCertIdKey;

@interface AutumnOpsCertPanelView () <UIDocumentPickerDelegate>
@property (nonatomic, strong) AutumnOpsClient *client;
@property (nonatomic, strong) AutumnOpsSiteEntry *siteEntry;
@property (nonatomic, strong) AutumnOpsSiteStore *siteStore;
@property (nonatomic, copy) AutumnOpsPanelToast toast;
@property (nonatomic, copy) AutumnOpsPanelBusy setBusy;
@property (nonatomic, copy) void (^onNeedRefresh)(void);
@property (nonatomic, copy) void (^onLastCertRevoked)(void);

@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *rootStack;
@property (nonatomic, strong) AutumnOpsSectionCardView *devicesCard;
@property (nonatomic, strong) UIStackView *devicesStack;
@property (nonatomic, strong) AutumnOpsSectionCardView *issueCard;
@property (nonatomic, strong) AutumnOpsFusedFieldActionView *issueFused;
@property (nonatomic, strong) UIView *issueResultBox;
@property (nonatomic, strong) UILabel *issueResultTitle;
@property (nonatomic, strong) UILabel *issueResultSecret;
@property (nonatomic, strong) AutumnOpsSectionCardView *shareCard;
@property (nonatomic, strong) AutumnOpsFusedFieldActionView *passFused;

@property (nonatomic, copy) NSArray<NSDictionary *> *certs;
@property (nonatomic) NSInteger activeCount;
@property (nonatomic, strong, nullable) AutumnOpsClaimIssueResult *lastIssue;
@end

@implementation AutumnOpsCertPanelView

- (instancetype)initWithClient:(AutumnOpsClient *)client
                     siteEntry:(AutumnOpsSiteEntry *)siteEntry
                     siteStore:(AutumnOpsSiteStore *)siteStore
                         toast:(AutumnOpsPanelToast)toast
                       setBusy:(AutumnOpsPanelBusy)setBusy
                 onNeedRefresh:(void (^)(void))onNeedRefresh
              onLastCertRevoked:(void (^)(void))onLastCertRevoked {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _client = client;
    _siteEntry = siteEntry;
    _siteStore = siteStore;
    _toast = [toast copy];
    _setBusy = [setBusy copy];
    _onNeedRefresh = [onNeedRefresh copy];
    _onLastCertRevoked = [onLastCertRevoked copy];
    _certs = @[];
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
  [rc addTarget:self action:@selector(_pullRefresh) forControlEvents:UIControlEventValueChanged];
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

  _devicesCard = [[AutumnOpsSectionCardView alloc] initWithTitle:@"已登记设备" body:@""];
  _devicesStack = [UIStackView new];
  _devicesStack.axis = UILayoutConstraintAxisVertical;
  _devicesStack.spacing = 0;
  [_devicesCard.contentStack addArrangedSubview:_devicesStack];
  [_rootStack addArrangedSubview:_devicesCard];

  _issueCard = [[AutumnOpsSectionCardView alloc]
      initWithTitle:@"① 签发认领码（给同事 / 新设备）"
               body:@"新设备会自建密钥，可单独吊销。流程：本页签发 → 把认领码发给对方 →"
                    @"对方首页「+」探测同一地址 → 选「认领码」粘贴。约 30 分钟有效，一次性。"
                    @"「设备标签」只是备注名，不是认领码。"];
  _issueFused = [[AutumnOpsFusedFieldActionView alloc] initWithHint:@"设备标签（选填，如：办公室平板）"
                                                       actionTitle:@"签发认领码"
                                                            target:self
                                                            action:@selector(_issueClaim)];
  _issueFused.textField.text = @"新设备";
  [_issueCard.contentStack addArrangedSubview:_issueFused];

  _issueResultBox = [UIView new];
  _issueResultBox.backgroundColor = [AutumnOpsUITheme.primaryContainer colorWithAlphaComponent:0.35];
  _issueResultBox.layer.cornerRadius = 10;
  _issueResultBox.hidden = YES;
  UIStackView *issueInner = [UIStackView new];
  issueInner.axis = UILayoutConstraintAxisVertical;
  issueInner.spacing = 8;
  _issueResultTitle = [UILabel new];
  _issueResultTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
  _issueResultTitle.numberOfLines = 0;
  _issueResultTitle.textColor = AutumnOpsUITheme.onSurface;
  _issueResultSecret = [UILabel new];
  _issueResultSecret.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
  _issueResultSecret.numberOfLines = 0;
  _issueResultSecret.textColor = AutumnOpsUITheme.onSurface;
  UIButton *copyBtn = [AutumnOpsUIControls buttonWithTitle:@"复制"
                                                     style:AutumnOpsButtonStyleOutlined
                                                    target:self
                                                    action:@selector(_copyClaim)];
  UIButton *shareSteps = [AutumnOpsUIControls buttonWithTitle:@"分享步骤+认领码"
                                                        style:AutumnOpsButtonStyleOutlined
                                                       target:self
                                                       action:@selector(_shareClaimSteps)];
  UIStackView *issueActions = [[UIStackView alloc] initWithArrangedSubviews:@[ copyBtn, shareSteps ]];
  issueActions.axis = UILayoutConstraintAxisHorizontal;
  issueActions.spacing = 8;
  [issueInner addArrangedSubview:_issueResultTitle];
  [issueInner addArrangedSubview:_issueResultSecret];
  [issueInner addArrangedSubview:issueActions];
  [_issueResultBox addSubview:issueInner];
  [issueInner mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_issueResultBox).insets(UIEdgeInsetsMake(12, 12, 12, 12));
  }];
  [_issueCard.contentStack addArrangedSubview:_issueResultBox];
  [_rootStack addArrangedSubview:_issueCard];

  _shareCard = [[AutumnOpsSectionCardView alloc]
      initWithTitle:@"② 分享运维密钥（同证）"
               body:@"用分享口令包裹本机运维密钥后发到宿主聊天会话（消息类型 AutumnOps，同一 certId）。"
                    @"对端点开运维卡并输入同一口令即可导入。口令不当场写入消息。"
                    @"给同事单独一台机请用上方① 认领码。"];
  _passFused = [[AutumnOpsFusedFieldActionView alloc] initWithHint:@"分享口令（加密密钥，导入时再输入）"
                                                      actionTitle:@"分享到聊天"
                                                           target:self
                                                           action:@selector(_shareToChat)];
  [_passFused setObscure:YES];
  [_shareCard.contentStack addArrangedSubview:_passFused];

  UILabel *fileHint = [UILabel new];
  fileHint.text = @"也可导出本机凭证文件（非聊天入口），或选文件覆盖导入到本站点。";
  fileHint.numberOfLines = 0;
  fileHint.font = [UIFont systemFontOfSize:12];
  fileHint.textColor = AutumnOpsUITheme.onSurfaceVariant;
  [_shareCard.contentStack addArrangedSubview:fileHint];
  [_shareCard.contentStack setCustomSpacing:8 afterView:_passFused];
  [_shareCard.contentStack setCustomSpacing:10 afterView:fileHint];

  UIButton *exportBtn = [AutumnOpsUIControls buttonWithTitle:@"导出运维凭证文件"
                                                       style:AutumnOpsButtonStyleOutlined
                                                      target:self
                                                      action:@selector(_exportFile)];
  UIButton *importBtn = [AutumnOpsUIControls buttonWithTitle:@"选凭证文件覆盖到本站点"
                                                       style:AutumnOpsButtonStyleOutlined
                                                      target:self
                                                      action:@selector(_pickImport)];
  UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [clearBtn setTitle:@"清除本机证书" forState:UIControlStateNormal];
  [clearBtn setTitleColor:AutumnOpsUITheme.error forState:UIControlStateNormal];
  clearBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
  clearBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
  [clearBtn addTarget:self action:@selector(_clearLocal) forControlEvents:UIControlEventTouchUpInside];
  [_shareCard.contentStack addArrangedSubview:exportBtn];
  [_shareCard.contentStack addArrangedSubview:importBtn];
  [_shareCard.contentStack setCustomSpacing:8 afterView:exportBtn];
  [_shareCard.contentStack setCustomSpacing:4 afterView:importBtn];
  [_shareCard.contentStack addArrangedSubview:clearBtn];
  [_rootStack addArrangedSubview:_shareCard];

  [self _rebuildDevices];
}

- (void)_pullRefresh {
  if (self.onNeedRefresh) self.onNeedRefresh();
  else [self reload];
}

- (void)applyCerts:(NSArray<NSDictionary *> *)certs activeCount:(NSInteger)activeCount {
  self.certs = certs ?: @[];
  self.activeCount = activeCount;
  if (self.scroll.refreshControl.refreshing) [self.scroll.refreshControl endRefreshing];
  [self _rebuildDevices];
}

- (void)reload {
  if (self.setBusy) self.setBusy(YES);
  __weak typeof(self) weakSelf = self;
  [self.client ensureSession:^(NSError *sessErr) {
    if (sessErr) {
      if (weakSelf.setBusy) weakSelf.setBusy(NO);
      if (weakSelf.scroll.refreshControl.refreshing) [weakSelf.scroll.refreshControl endRefreshing];
      if (weakSelf.toast) weakSelf.toast(sessErr.localizedDescription);
      return;
    }
    [weakSelf.client certList:^(NSDictionary *data, NSError *err) {
      if (weakSelf.setBusy) weakSelf.setBusy(NO);
      if (weakSelf.scroll.refreshControl.refreshing) [weakSelf.scroll.refreshControl endRefreshing];
      if (err) {
        if (weakSelf.toast) weakSelf.toast(err.localizedDescription);
        return;
      }
      NSArray *list = [data[@"list"] isKindOfClass:[NSArray class]] ? data[@"list"] : @[];
      NSMutableArray *maps = [NSMutableArray array];
      for (id o in list) if ([o isKindOfClass:[NSDictionary class]]) [maps addObject:o];
      NSInteger active = [data[@"activeCount"] respondsToSelector:@selector(integerValue)] ? [data[@"activeCount"] integerValue] : maps.count;
      [weakSelf applyCerts:maps activeCount:active];
    }];
  }];
}

- (void)_rebuildDevices {
  for (UIView *v in [self.devicesStack.arrangedSubviews copy]) {
    [self.devicesStack removeArrangedSubview:v];
    [v removeFromSuperview];
  }
  [self.devicesCard setBodyText:[NSString stringWithFormat:@"当前有效 %ld 台。列表中的「标签」来自签发时填写的设备名；吊销后该设备无法再建运维会话。", (long)self.activeCount]];
  if (self.certs.count == 0) {
    UILabel *empty = [UILabel new];
    empty.text = @"暂无设备";
    empty.font = [UIFont systemFontOfSize:14];
    empty.textColor = AutumnOpsUITheme.onSurfaceVariant;
    [self.devicesStack addArrangedSubview:empty];
    return;
  }
  AutumnOpsCredentialBundle *b = [self.client currentBundle:nil];
  NSString *selfId = b.certId.length ? b.certId : self.siteEntry.certId;
  for (NSDictionary *c in self.certs) {
    BOOL revoked = [c[@"revoked"] boolValue];
    NSString *cid = [NSString stringWithFormat:@"%@", c[@"certId"] ?: @""];
    BOOL isSelf = [c[@"self"] boolValue] || (selfId.length && [cid isEqualToString:selfId]);
    NSString *title = [NSString stringWithFormat:@"%@", c[@"label"] ?: cid];
    NSString *sub = [NSString stringWithFormat:@"%@证书标识 %@%@",
                     isSelf ? @"本机 · " : @"其他设备 · ",
                     cid,
                     revoked ? @" · 已吊销" : @""];
    AutumnOpsRuleRowChromeView *row =
        [[AutumnOpsRuleRowChromeView alloc] initWithTitle:title
                                                 subtitle:sub
                                                   active:!revoked && isSelf
                                              statusLabel:revoked ? @"已吊销" : (isSelf ? @"本机" : @"有效")
                                           titleMonospace:NO];
    [row setHighlightedBorder:isSelf && !revoked];
    if (!revoked) {
      UIButton *rev = [AutumnOpsRuleRowChromeView destructiveTextAction:@"吊销" target:self action:@selector(_revoke:)];
      objc_setAssociatedObject(rev, kCertIdKey, cid, OBJC_ASSOCIATION_COPY_NONATOMIC);
      [row setActionViews:@[ rev ]];
    }
    [self.devicesStack addArrangedSubview:row];
  }
}

- (void)_confirm:(NSString *)title body:(NSString *)body ok:(void (^)(void))ok {
  UIViewController *host = [self _hostVC];
  if (!host) return;
  [AutumnOpsConfirmPresenter presentFrom:host title:title body:body destructive:YES onConfirm:ok];
}

- (void)_revoke:(UIButton *)sender {
  NSString *cid = objc_getAssociatedObject(sender, kCertIdKey) ?: @"";
  BOOL lastOne = self.activeCount <= 1;
  NSString *title = lastOne ? @"吊销最后一张有效证书" : @"吊销证书";
  NSString *body = lastOne
      ? @"这是最后一张有效证。吊销后所有运维设备将无法登录证书通道，只能通过防火墙/数据库重置恢复。确定吊销？"
      : [NSString stringWithFormat:@"确定吊销 %@？该设备将无法再建运维会话。", cid];
  __weak typeof(self) weakSelf = self;
  [self _confirm:title body:body ok:^{
    if (weakSelf.setBusy) weakSelf.setBusy(YES);
    [weakSelf.client certRevoke:cid completion:^(AutumnOpsRevokeResult *result, NSError *error) {
      if (weakSelf.setBusy) weakSelf.setBusy(NO);
      if (error) {
        if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
        return;
      }
      if (result.lastCert) {
        if (weakSelf.toast) weakSelf.toast(@"已吊销最后一张有效证");
        if (weakSelf.onLastCertRevoked) weakSelf.onLastCertRevoked();
      } else {
        if (weakSelf.toast) weakSelf.toast(@"已吊销");
        if (weakSelf.onNeedRefresh) weakSelf.onNeedRefresh();
        else [weakSelf reload];
      }
    }];
  }];
}

- (void)_issueClaim {
  NSString *label = self.issueFused.textField.text ?: @"";
  AutumnOpsValidateResult *vr = [AutumnOpsValidators deviceLabel:label];
  if (!vr.ok) {
    if (self.toast) self.toast(vr.error);
    return;
  }
  NSString *use = [label stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (!use.length) use = @"新设备";
  if (self.setBusy) self.setBusy(YES);
  __weak typeof(self) weakSelf = self;
  [self.client certIssueWithLabel:use completion:^(AutumnOpsClaimIssueResult *result, NSError *error) {
    if (weakSelf.setBusy) weakSelf.setBusy(NO);
    if (error) {
      if (weakSelf.toast) weakSelf.toast(error.localizedDescription);
      return;
    }
    weakSelf.lastIssue = result;
    NSString *lab = result.label.length ? result.label : use;
    weakSelf.issueResultTitle.text = [NSString stringWithFormat:@"认领码（仅显示一次） · %@", lab];
    weakSelf.issueResultSecret.text = result.claimSecret;
    weakSelf.issueResultBox.hidden = NO;
    UIPasteboard.generalPasteboard.string = result.claimSecret ?: @"";
    if (weakSelf.toast) weakSelf.toast(@"已签发认领码（约 30 分钟有效）");
  }];
}

- (void)_copyClaim {
  if (!self.lastIssue.claimSecret.length) return;
  UIPasteboard.generalPasteboard.string = self.lastIssue.claimSecret;
  if (self.toast) self.toast(@"已复制认领码");
}

- (void)_shareClaimSteps {
  if (!self.lastIssue.claimSecret.length) return;
  NSString *text = [NSString stringWithFormat:
      @"【Autumn 运维 · 认领码】约 30 分钟有效\n"
      @"1. 打开 Autumn 运维 → 右上角「+」\n"
      @"2. 填写站点：%@\n"
      @"3. 点「探测」→ 选「认领码」\n"
      @"4. 粘贴认领码：%@\n"
      @"（这是文字认领码，不是运维密钥消息）",
      self.client.baseUrl ?: @"",
      self.lastIssue.claimSecret];
  UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[ text ] applicationActivities:nil];
  av.popoverPresentationController.sourceView = self;
  [[self _hostVC] presentViewController:av animated:YES completion:nil];
}

- (void)_shareToChat {
  AutumnOpsShareToChatBlock hook = AutumnOpsShareHooks.toChat;
  if (!hook) {
    if (self.toast) self.toast(@"当前 App 未接入「分享到聊天」");
    return;
  }
  NSString *pass = self.passFused.textField.text;
  AutumnOpsValidateResult *vr = [AutumnOpsValidators sharePassphrase:pass];
  if (!vr.ok) {
    if (self.toast) self.toast(vr.error);
    return;
  }
  NSError *err = nil;
  NSString *wrapped = [self.client exportWrappedWithPassphrase:pass error:&err];
  if (!wrapped) {
    if (self.toast) self.toast(err.localizedDescription);
    return;
  }
  AutumnOpsCredentialBundle *b = [self.client currentBundle:nil];
  NSDictionary *content = [AutumnOpsPayload toMessageMapWithWrapped:wrapped
                                                            baseUrl:self.client.baseUrl
                                                             siteId:b.siteId
                                                             certId:b.certId
                                                 serverFingerprint:b.serverFingerprint
                                                       createdAtMs:@((long long)([[NSDate date] timeIntervalSince1970] * 1000))];
  __weak typeof(self) weakSelf = self;
  hook([self _hostVC], content, ^(BOOL ok) {
    if (weakSelf.toast) weakSelf.toast(ok ? @"已打开分享到聊天" : @"未完成分享");
  });
}

- (void)_exportFile {
  NSString *pass = self.passFused.textField.text;
  AutumnOpsValidateResult *vr = [AutumnOpsValidators sharePassphrase:pass];
  if (!vr.ok) {
    if (self.toast) self.toast(vr.error);
    return;
  }
  NSError *err = nil;
  NSString *wrapped = [self.client exportWrappedWithPassphrase:pass error:&err];
  if (!wrapped) {
    if (self.toast) self.toast(err.localizedDescription);
    return;
  }
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
  UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[ tmp ] applicationActivities:nil];
  av.popoverPresentationController.sourceView = self;
  [[self _hostVC] presentViewController:av animated:YES completion:nil];
  if (self.toast) self.toast(@"已导出运维凭证文件");
}

- (void)_pickImport {
  NSString *pass = self.passFused.textField.text;
  AutumnOpsValidateResult *vr = [AutumnOpsValidators sharePassphrase:pass];
  if (!vr.ok) {
    if (self.toast) self.toast(vr.error);
    return;
  }
  UTType *t = [UTType typeWithFilenameExtension:@"autumnops"] ?: UTTypeJSON;
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[ t, UTTypeJSON ]];
  picker.delegate = self;
  [[self _hostVC] presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  NSURL *url = urls.firstObject;
  [url startAccessingSecurityScopedResource];
  NSData *data = [NSData dataWithContentsOfURL:url];
  [url stopAccessingSecurityScopedResource];
  NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  AutumnOpsParseResult *parsed = [AutumnOpsParseResult parse:raw ?: @""];
  if (!parsed.ok) {
    if (self.toast) self.toast(parsed.error ?: @"凭证文件无效");
    return;
  }
  NSString *pass = [self.passFused.textField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSError *err = nil;
  if (![self.client importWrapped:parsed.payload.wrapped passphrase:pass error:&err]) {
    if (self.toast) self.toast(err.localizedDescription ?: @"导入失败");
    return;
  }
  AutumnOpsCredentialBundle *b = [self.client currentBundle:nil];
  self.siteEntry.enrolled = YES;
  if (b.certId.length) self.siteEntry.certId = b.certId;
  if (b.siteId.length) self.siteEntry.siteId = b.siteId;
  if (b.serverFingerprint.length) self.siteEntry.serverFingerprint = b.serverFingerprint;
  [self.siteStore upsertSite:self.siteEntry error:nil];
  NSString *name = url.lastPathComponent ?: @"凭证";
  if (self.toast) self.toast([NSString stringWithFormat:@"已从 %@ 覆盖导入", name]);
  if (self.onNeedRefresh) self.onNeedRefresh();
  else [self reload];
}

- (void)_clearLocal {
  __weak typeof(self) weakSelf = self;
  [self _confirm:@"清除本机证书"
            body:@"仅删除本机私钥包，不会吊销服务端登记。若这是唯一设备且无其它凭证，需防火墙重置才能再入驻。确定？"
              ok:^{
    [weakSelf.client.store clear:nil];
    if (weakSelf.siteEntry && weakSelf.siteStore) {
      weakSelf.siteEntry.enrolled = NO;
      weakSelf.siteEntry.certId = nil;
      [weakSelf.siteStore upsertSite:weakSelf.siteEntry error:nil];
    }
    if (weakSelf.onLastCertRevoked) {
      weakSelf.onLastCertRevoked();
      return;
    }
    AutumnOpsRecoveryViewController *vc =
        [[AutumnOpsRecoveryViewController alloc] initWithSiteTitle:weakSelf.siteEntry.title baseUrl:weakSelf.client.baseUrl];
    UIViewController *host = [weakSelf _hostVC];
    NSMutableArray *stack = [(host.navigationController.viewControllers ?: @[]) mutableCopy];
    if (stack.count) [stack removeLastObject];
    [stack addObject:vc];
    [host.navigationController setViewControllers:stack animated:YES];
  }];
}

@end
