#import "AutumnOpsRecoveryViewController.h"
#import "AutumnOpsPageChromeView.h"
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
    make.edges.equalTo(scroll).insets(UIEdgeInsetsMake(16, 16, 16, 16));
    make.width.equalTo(scroll).offset(-32);
  }];

  if (self.baseUrl.length) {
    UILabel *u = [UILabel new];
    u.text = [NSString stringWithFormat:@"站点：%@", self.baseUrl];
    u.textColor = UIColor.secondaryLabelColor;
    u.numberOfLines = 0;
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
  extra.text = @"若 IP 已锁死、无法登录运维墙";
  [stack addArrangedSubview:extra];
  [stack addArrangedSubview:[self _body:@"在数据库执行下列语句后重启 Autumn，日志会出现新的入驻口令；"
                          @"仅重启不够（库中仍有已入驻设备时不会重发临时口令）。"]];
  UILabel *sql = [UILabel new];
  sql.numberOfLines = 0;
  sql.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  sql.text = kAutumnOpsRecoverySQL;
  sql.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:1];
  [stack addArrangedSubview:sql];
  UIButton *copy = [UIButton buttonWithType:UIButtonTypeSystem];
  [copy setTitle:@"复制数据库语句" forState:UIControlStateNormal];
  [copy addTarget:self action:@selector(_copySQL) forControlEvents:UIControlEventTouchUpInside];
  [stack addArrangedSubview:copy];
}

- (UILabel *)_body:(NSString *)t {
  UILabel *l = [UILabel new];
  l.numberOfLines = 0;
  l.font = [UIFont systemFontOfSize:15];
  l.text = t;
  return l;
}

- (UIView *)_step:(NSInteger)n title:(NSString *)title body:(NSString *)body {
  UIStackView *s = [UIStackView new];
  s.axis = UILayoutConstraintAxisVertical;
  s.spacing = 4;
  UILabel *h = [UILabel new];
  h.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  h.text = [NSString stringWithFormat:@"%ld. %@", (long)n, title];
  UILabel *b = [self _body:body];
  b.font = [UIFont systemFontOfSize:14];
  b.textColor = UIColor.secondaryLabelColor;
  [s addArrangedSubview:h];
  [s addArrangedSubview:b];
  return s;
}

- (void)_copySQL {
  UIPasteboard.generalPasteboard.string = kAutumnOpsRecoverySQL;
  UIAlertController *a = [UIAlertController alertControllerWithTitle:nil message:@"已复制数据库语句" preferredStyle:UIAlertControllerStyleAlert];
  [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:a animated:YES completion:nil];
}

@end
