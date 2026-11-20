#import "AutumnOpsRecoveryViewController.h"
#import "AutumnOpsPageChromeView.h"
#import "AutumnOpsUIControls.h"
#import "AutumnOpsUITheme.h"
#import <Masonry/Masonry.h>

static NSString * const kAutumnOpsRecoverySQL =
  @"UPDATE sys_config SET param_value = '{}' WHERE param_key = 'SECURITY_OPS_CERT_CONFIG';";

@interface AutumnOpsRecoveryViewController ()
@property (nonatomic, copy, nullable) NSString *siteTitle;
@property (nonatomic, copy, nullable) NSString *baseUrl;
@property (nonatomic, strong, nullable) AutumnOpsPageChromeView *pageChrome;
@end

@implementation AutumnOpsRecoveryViewController

- (instancetype)initWithSiteTitle:(NSString *)title baseUrl:(NSString *)baseUrl {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _siteTitle = title;
    _baseUrl = baseUrl;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  NSString *title = self.siteTitle.length ? [NSString stringWithFormat:@"恢复：%@", self.siteTitle] : @"恢复运维证书";
  self.title = title;
  _pageChrome = [AutumnOpsPageChromeView installOnViewController:self title:title rightItems:nil];

  UIScrollView *scroll = [UIScrollView new];
  [self.view addSubview:scroll];
  [scroll mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.bottom.equalTo(self.view);
    if (_pageChrome) make.top.equalTo(_pageChrome.mas_bottom);
    else make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
  }];
  UIStackView *stack = [UIStackView new];
  stack.axis = UILayoutConstraintAxisVertical;
  stack.spacing = 12;
  [scroll addSubview:stack];
  [stack mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(scroll).insets(UIEdgeInsetsMake(16, 16, 28, 16));
    make.width.equalTo(scroll).offset(-32);
  }];

  if (self.baseUrl.length) {
    UILabel *u = [UILabel new];
    u.text = [NSString stringWithFormat:@"站点：%@", self.baseUrl];
    u.textColor = AutumnOpsUITheme.onSurfaceVariant;
    u.numberOfLines = 0;
    u.font = [UIFont systemFontOfSize:14];
    [stack addArrangedSubview:u];
  }
  [stack addArrangedSubview:[self _body:@"本机证书已不可用（清除、卸装或吊销了最后一张有效证）。"
                          @"服务端不会通过网络下发私钥，需重新打开入驻窗口。"]];
  [stack addArrangedSubview:[self _step:1 title:@"优先：运维墙重置"
                                   body:@"用超级管理员账号登录该站运维墙，打开运维证书状态，"
                                        @"填写系统加固中的「清除确认令牌」，执行「重置运维证书」。"]];
  [stack addArrangedSubview:[self _step:2 title:@"复制新的入驻口令"
                                   body:@"重置成功后，查看服务器控制台日志中的一行：OpsEnroll secret=…"
                                        @"（仅打印一次，请立即复制口令部分）。"]];
  [stack addArrangedSubview:[self _step:3 title:@"在本 App 重新入驻"
                                   body:@"返回「添加站点」→ 填写同一地址 → 探测 → 粘贴新的入驻口令 → 入驻。"]];

  UILabel *extra = [UILabel new];
  extra.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  extra.textColor = AutumnOpsUITheme.onSurface;
  extra.text = @"若 IP 已锁死、无法登录运维墙";
  [stack addArrangedSubview:extra];
  [stack addArrangedSubview:[self _body:@"在数据库执行下列语句后重启 Autumn，日志会出现新的入驻口令；"
                          @"仅重启不够（库中仍有已入驻设备时不会重发临时口令）。"]];

  UITextView *sql = [UITextView new];
  sql.text = kAutumnOpsRecoverySQL;
  sql.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  sql.textColor = AutumnOpsUITheme.onSurface;
  sql.backgroundColor = [AutumnOpsUITheme.surfaceContainerHighest colorWithAlphaComponent:0.55];
  sql.editable = NO;
  sql.scrollEnabled = NO;
  sql.textContainerInset = UIEdgeInsetsMake(12, 10, 12, 10);
  sql.layer.cornerRadius = 8;
  sql.clipsToBounds = YES;
  [stack addArrangedSubview:sql];

  UIButton *copy = [AutumnOpsUIControls buttonWithTitle:@"复制数据库语句"
                                                  style:AutumnOpsButtonStyleOutlined
                                                 target:self
                                                 action:@selector(_copySQL)];
  [stack addArrangedSubview:copy];
  [stack setCustomSpacing:8 afterView:sql];
  [stack setCustomSpacing:24 afterView:copy];

  UIButton *done = [AutumnOpsUIControls buttonWithTitle:@"我知道了"
                                                  style:AutumnOpsButtonStyleFilled
                                                 target:self
                                                 action:@selector(_done)];
  [stack addArrangedSubview:done];
}

- (UILabel *)_body:(NSString *)t {
  UILabel *l = [UILabel new];
  l.numberOfLines = 0;
  l.font = [UIFont systemFontOfSize:15];
  l.textColor = AutumnOpsUITheme.onSurface;
  l.text = t;
  return l;
}

- (UIView *)_step:(NSInteger)n title:(NSString *)title body:(NSString *)body {
  UILabel *num = [UILabel new];
  num.text = [NSString stringWithFormat:@"%ld", (long)n];
  num.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
  num.textColor = AutumnOpsUITheme.onPrimary;
  num.textAlignment = NSTextAlignmentCenter;
  UIView *badge = [UIView new];
  badge.backgroundColor = AutumnOpsUITheme.primary;
  badge.layer.cornerRadius = 14;
  badge.clipsToBounds = YES;
  [badge addSubview:num];
  num.translatesAutoresizingMaskIntoConstraints = NO;
  badge.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [badge.widthAnchor constraintEqualToConstant:28],
    [badge.heightAnchor constraintEqualToConstant:28],
    [num.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
    [num.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
  ]];

  UILabel *h = [UILabel new];
  h.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  h.textColor = AutumnOpsUITheme.onSurface;
  h.text = title;
  UILabel *b = [UILabel new];
  b.numberOfLines = 0;
  b.font = [UIFont systemFontOfSize:13];
  b.textColor = AutumnOpsUITheme.onSurfaceVariant;
  b.text = body;
  UIStackView *textCol = [[UIStackView alloc] initWithArrangedSubviews:@[ h, b ]];
  textCol.axis = UILayoutConstraintAxisVertical;
  textCol.spacing = 4;

  UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ badge, textCol ]];
  row.axis = UILayoutConstraintAxisHorizontal;
  row.alignment = UIStackViewAlignmentTop;
  row.spacing = 12;
  UIView *wrap = [UIView new];
  [wrap addSubview:row];
  row.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [row.topAnchor constraintEqualToAnchor:wrap.topAnchor],
    [row.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor],
    [row.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor],
    [row.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-4],
  ]];
  return wrap;
}

- (void)_toast:(NSString *)msg {
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

- (void)_copySQL {
  UIPasteboard.generalPasteboard.string = kAutumnOpsRecoverySQL;
  [self _toast:@"已复制数据库语句"];
}

- (void)_done {
  if (self.navigationController) {
    [self.navigationController popViewControllerAnimated:YES];
  } else {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

@end
