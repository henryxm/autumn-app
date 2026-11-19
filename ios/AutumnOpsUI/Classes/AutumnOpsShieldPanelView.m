#import "AutumnOpsShieldPanelView.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>

@interface AutumnOpsShieldPanelView () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) AutumnOpsClient *client;
@property (nonatomic, copy) AutumnOpsPanelToast toast;
@property (nonatomic, copy) AutumnOpsPanelBusy setBusy;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UISwitch *attackSwitch;
@property (nonatomic, strong) UISwitch *printSwitch;
@property (nonatomic, strong) UITextField *uriField;
@property (nonatomic, strong) UITextField *autoField;
@property (nonatomic, strong) UILabel *countChip;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@property (nonatomic) BOOL attack;
@property (nonatomic) BOOL printOn;
@property (nonatomic) BOOL enableOn;
@property (nonatomic) NSInteger totalCount;
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
    _rows = @[];
    [self _build];
  }
  return self;
}

- (void)_build {
  self.backgroundColor = UIColor.systemGroupedBackgroundColor;
  _scroll = [UIScrollView new];
  _scroll.alwaysBounceVertical = YES;
  UIRefreshControl *rc = [UIRefreshControl new];
  [rc addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
  _scroll.refreshControl = rc;
  _content = [UIView new];
  [self addSubview:_scroll];
  [_scroll addSubview:_content];
  [_scroll mas_makeConstraints:^(MASConstraintMaker *make) { make.edges.equalTo(self); }];
  [_content mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_scroll);
    make.width.equalTo(_scroll);
  }];

  UILabel *title = [self _title:@"攻击防御"];
  UILabel *desc = [self _desc:@"配置需防护的资源路径；总开关写库生效，攻击模式与打印为运行时开关。"];

  UIView *settings = [self _card];
  _enableSwitch = [UISwitch new];
  _attackSwitch = [UISwitch new];
  _printSwitch = [UISwitch new];
  [_enableSwitch addTarget:self action:@selector(_enableChanged) forControlEvents:UIControlEventValueChanged];
  [_attackSwitch addTarget:self action:@selector(_attackChanged) forControlEvents:UIControlEventValueChanged];
  [_printSwitch addTarget:self action:@selector(_printChanged) forControlEvents:UIControlEventValueChanged];
  UIStackView *settingsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
    [self _switchRow:@"总开关" sub:@"启用或关闭默认盾牌规则集" sw:_enableSwitch],
    [self _switchRow:@"攻击模式" sub:@"对未放行 IP 拦截匹配资源" sw:_attackSwitch],
    [self _switchRow:@"打印日志" sub:@"拦截与放行时输出防护日志" sw:_printSwitch],
  ]];
  settingsStack.axis = UILayoutConstraintAxisVertical;
  settingsStack.spacing = 8;
  UILabel *setTitle = [UILabel new];
  setTitle.text = @"运行开关";
  setTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
  UILabel *setBody = [self _desc:@"总开关写入数据库；攻击模式与打印仅影响当前进程内存。"];
  UIStackView *setInner = [[UIStackView alloc] initWithArrangedSubviews:@[setTitle, setBody, settingsStack]];
  setInner.axis = UILayoutConstraintAxisVertical;
  setInner.spacing = 8;
  [settings addSubview:setInner];
  [setInner mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(settings).insets(UIEdgeInsetsMake(14, 16, 16, 16));
  }];

  UIView *fused = [self _fusedBar];
  _countChip = [self _chip:@"暂无规则"];
  _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  _table.dataSource = self;
  _table.delegate = self;
  _table.scrollEnabled = NO;
  _table.separatorStyle = UITableViewCellSeparatorStyleNone;
  _table.backgroundColor = UIColor.clearColor;
  [_table registerClass:UITableViewCell.class forCellReuseIdentifier:@"rule"];

  UIStackView *root = [[UIStackView alloc] initWithArrangedSubviews:@[title, desc, settings, fused, _countChip, _table]];
  root.axis = UILayoutConstraintAxisVertical;
  root.spacing = 12;
  root.alignment = UIStackViewAlignmentFill;
  [_content addSubview:root];
  [root mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_content).insets(UIEdgeInsetsMake(12, 16, 28, 16));
  }];
  [_table mas_makeConstraints:^(MASConstraintMaker *make) {
    make.height.mas_equalTo(1).priorityLow();
  }];
}

- (UILabel *)_title:(NSString *)t {
  UILabel *l = [UILabel new];
  l.text = t;
  l.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
  return l;
}

- (UILabel *)_desc:(NSString *)t {
  UILabel *l = [UILabel new];
  l.text = t;
  l.numberOfLines = 0;
  l.font = [UIFont systemFontOfSize:13];
  l.textColor = UIColor.secondaryLabelColor;
  return l;
}

- (UIView *)_card {
  UIView *v = [UIView new];
  v.backgroundColor = [UIColor.secondarySystemGroupedBackgroundColor colorWithAlphaComponent:0.9];
  v.layer.cornerRadius = 14;
  return v;
}

- (UIView *)_switchRow:(NSString *)title sub:(NSString *)sub sw:(UISwitch *)sw {
  UILabel *t = [UILabel new];
  t.text = title;
  t.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  UILabel *s = [UILabel new];
  s.text = sub;
  s.font = [UIFont systemFontOfSize:12];
  s.textColor = UIColor.secondaryLabelColor;
  s.numberOfLines = 0;
  UIStackView *left = [[UIStackView alloc] initWithArrangedSubviews:@[t, s]];
  left.axis = UILayoutConstraintAxisVertical;
  left.spacing = 2;
  UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[left, sw]];
  row.axis = UILayoutConstraintAxisHorizontal;
  row.alignment = UIStackViewAlignmentCenter;
  row.spacing = 8;
  [left setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  return row;
}

- (UIView *)_fusedBar {
  UIView *bar = [UIView new];
  bar.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
  bar.layer.cornerRadius = 12;
  bar.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
  bar.layer.borderColor = UIColor.separatorColor.CGColor;
  bar.clipsToBounds = YES;
  _uriField = [UITextField new];
  _uriField.placeholder = @"资源路径，如 /";
  _uriField.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
  _uriField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  _uriField.autocorrectionType = UITextAutocorrectionTypeNo;
  _autoField = [UITextField new];
  _autoField.placeholder = @"自动阈值";
  _autoField.text = @"10000";
  _autoField.keyboardType = UIKeyboardTypeNumberPad;
  _autoField.font = [UIFont systemFontOfSize:15];
  UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
  [add setTitle:@"添加" forState:UIControlStateNormal];
  add.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  [add addTarget:self action:@selector(_addRule) forControlEvents:UIControlEventTouchUpInside];
  UIView *d1 = [UIView new];
  d1.backgroundColor = UIColor.separatorColor;
  UIView *d2 = [UIView new];
  d2.backgroundColor = UIColor.separatorColor;
  [_uriField mas_makeConstraints:^(MASConstraintMaker *make) {}];
  UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[_uriField, d1, _autoField, d2, add]];
  row.axis = UILayoutConstraintAxisHorizontal;
  row.alignment = UIStackViewAlignmentFill;
  row.spacing = 0;
  [bar addSubview:row];
  [row mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(bar);
    make.height.mas_equalTo(48);
  }];
  [d1 mas_makeConstraints:^(MASConstraintMaker *make) { make.width.mas_equalTo(1); }];
  [d2 mas_makeConstraints:^(MASConstraintMaker *make) { make.width.mas_equalTo(1); }];
  [_uriField mas_makeConstraints:^(MASConstraintMaker *make) { make.width.greaterThanOrEqualTo(@120); }];
  [_autoField mas_makeConstraints:^(MASConstraintMaker *make) { make.width.mas_equalTo(88); }];
  [add mas_makeConstraints:^(MASConstraintMaker *make) { make.width.mas_equalTo(64); }];
  UIView *padL = [UIView new];
  // inset fields via leftView
  _uriField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
  _uriField.leftViewMode = UITextFieldViewModeAlways;
  _autoField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 1)];
  _autoField.leftViewMode = UITextFieldViewModeAlways;
  (void)padL;
  return bar;
}

- (UILabel *)_chip:(NSString *)text {
  UILabel *l = [UILabel new];
  l.text = text;
  l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
  l.textColor = UIColor.secondaryLabelColor;
  l.backgroundColor = [UIColor.tertiarySystemFillColor colorWithAlphaComponent:0.9];
  l.layer.cornerRadius = 10;
  l.clipsToBounds = YES;
  l.textAlignment = NSTextAlignmentCenter;
  return l;
}

- (void)reload {
  self.setBusy(YES);
  [self.client shieldStatus:^(NSDictionary *status, NSError *e1) {
    if (e1) {
      self.setBusy(NO);
      [self.scroll.refreshControl endRefreshing];
      self.toast(e1.localizedDescription);
      return;
    }
    self.enableOn = [status[@"enable"] boolValue];
    self.attack = [status[@"attack"] boolValue];
    self.printOn = [status[@"print"] boolValue];
    self.enableSwitch.on = self.enableOn;
    self.attackSwitch.on = self.attack;
    self.printSwitch.on = self.printOn;
    [self.client shieldListPage:1 limit:100 completion:^(NSDictionary *page, NSError *e2) {
      self.setBusy(NO);
      [self.scroll.refreshControl endRefreshing];
      if (e2) {
        self.toast(e2.localizedDescription);
        return;
      }
      NSArray *list = [page[@"list"] isKindOfClass:[NSArray class]] ? page[@"list"] : @[];
      NSMutableArray *rows = [NSMutableArray array];
      for (id o in list) if ([o isKindOfClass:[NSDictionary class]]) [rows addObject:o];
      self.rows = rows;
      self.totalCount = [page[@"count"] respondsToSelector:@selector(integerValue)] ? [page[@"count"] integerValue] : rows.count;
      self.countChip.text = self.totalCount <= 0 ? @"  暂无规则  " : [NSString stringWithFormat:@"  共 %ld 条  ", (long)self.totalCount];
      [self.table reloadData];
      [self _updateTableHeight];
    }];
  }];
}

- (void)_updateTableHeight {
  [self.table layoutIfNeeded];
  CGFloat h = MAX(1, self.table.contentSize.height);
  [self.table mas_updateConstraints:^(MASConstraintMaker *make) {
    make.height.mas_equalTo(h);
  }];
}

- (void)_enableChanged {
  BOOL v = self.enableSwitch.on;
  self.setBusy(YES);
  [self.client shieldSetEnable:v completion:^(NSDictionary *data, NSError *error) {
    self.setBusy(NO);
    if (error) {
      self.enableSwitch.on = !v;
      self.toast(error.localizedDescription);
    }
  }];
}

- (void)_attackChanged {
  BOOL v = self.attackSwitch.on;
  self.setBusy(YES);
  [self.client shieldSetAttack:v completion:^(NSDictionary *data, NSError *error) {
    self.setBusy(NO);
    if (error) {
      self.attackSwitch.on = !v;
      self.toast(error.localizedDescription);
    }
  }];
}

- (void)_printChanged {
  BOOL v = self.printSwitch.on;
  self.setBusy(YES);
  [self.client shieldSetPrint:v completion:^(NSDictionary *data, NSError *error) {
    self.setBusy(NO);
    if (error) {
      self.printSwitch.on = !v;
      self.toast(error.localizedDescription);
    }
  }];
}

- (void)_addRule {
  NSString *uri = [self.uriField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSInteger autoV = self.autoField.text.integerValue;
  if (!uri.length) {
    self.toast(@"请填写资源路径，例如 / 或 /api");
    return;
  }
  if (autoV < 1000) {
    self.toast(@"自动阈值须不小于 1000");
    return;
  }
  self.setBusy(YES);
  [self.client shieldSaveUri:uri enable:YES autoValue:autoV completion:^(NSDictionary *data, NSError *error) {
    self.setBusy(NO);
    if (error) {
      self.toast(error.localizedDescription);
      return;
    }
    self.uriField.text = @"";
    self.toast([NSString stringWithFormat:@"已添加：%@", uri]);
    [self reload];
  }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rule" forIndexPath:indexPath];
  for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  cell.backgroundColor = UIColor.clearColor;
  NSDictionary *row = self.rows[indexPath.row];
  BOOL on = [row[@"enable"] boolValue];
  NSString *uri = [NSString stringWithFormat:@"%@", row[@"uri"] ?: @""];
  NSString *autoS = [NSString stringWithFormat:@"%@", row[@"auto"] ?: @"0"];

  UIView *card = [UIView new];
  card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
  card.layer.cornerRadius = 12;
  card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
  card.layer.borderColor = UIColor.separatorColor.CGColor;
  card.clipsToBounds = YES;
  UIView *bar = [UIView new];
  bar.backgroundColor = on ? UIColor.systemTealColor : UIColor.tertiaryLabelColor;
  UILabel *title = [UILabel new];
  title.text = uri;
  title.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightSemibold];
  UILabel *sub = [UILabel new];
  sub.text = [NSString stringWithFormat:@"自动阈值 · %@", autoS];
  sub.font = [UIFont systemFontOfSize:13];
  sub.textColor = UIColor.secondaryLabelColor;
  UILabel *pill = [UILabel new];
  pill.text = on ? @"  已开启  " : @"  已关闭  ";
  pill.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
  pill.textColor = on ? UIColor.systemTealColor : UIColor.secondaryLabelColor;
  pill.backgroundColor = [UIColor.tertiarySystemFillColor colorWithAlphaComponent:0.8];
  pill.layer.cornerRadius = 10;
  pill.clipsToBounds = YES;
  UIButton *toggle = [UIButton buttonWithType:UIButtonTypeSystem];
  [toggle setTitle:on ? @"关闭" : @"开启" forState:UIControlStateNormal];
  toggle.tag = indexPath.row;
  [toggle addTarget:self action:@selector(_toggle:) forControlEvents:UIControlEventTouchUpInside];
  UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
  [del setTitle:@"删除" forState:UIControlStateNormal];
  [del setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
  del.tag = indexPath.row;
  [del addTarget:self action:@selector(_delete:) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[toggle, del]];
  actions.axis = UILayoutConstraintAxisHorizontal;
  actions.spacing = 8;
  UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[title, pill]];
  top.axis = UILayoutConstraintAxisHorizontal;
  top.spacing = 6;
  top.alignment = UIStackViewAlignmentCenter;
  [title setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  UIStackView *col = [[UIStackView alloc] initWithArrangedSubviews:@[top, sub, actions]];
  col.axis = UILayoutConstraintAxisVertical;
  col.spacing = 6;
  [cell.contentView addSubview:card];
  [card addSubview:bar];
  [card addSubview:col];
  [card mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(cell.contentView).insets(UIEdgeInsetsMake(0, 0, 8, 0));
  }];
  [bar mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.top.bottom.equalTo(card);
    make.width.mas_equalTo(4);
  }];
  [col mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(card).insets(UIEdgeInsetsMake(10, 16, 8, 12));
  }];
  return cell;
}

- (void)_toggle:(UIButton *)sender {
  NSDictionary *row = self.rows[sender.tag];
  NSInteger sid = [row[@"id"] integerValue];
  BOOL next = ![row[@"enable"] boolValue];
  self.setBusy(YES);
  [self.client shieldUpdateId:sid uri:nil enable:@(next) autoValue:nil completion:^(NSDictionary *data, NSError *error) {
    self.setBusy(NO);
    if (error) self.toast(error.localizedDescription);
    else [self reload];
  }];
}

- (void)_delete:(UIButton *)sender {
  NSDictionary *row = self.rows[sender.tag];
  NSInteger sid = [row[@"id"] integerValue];
  NSString *uri = [NSString stringWithFormat:@"%@", row[@"uri"] ?: @""];
  UIAlertController *a = [UIAlertController alertControllerWithTitle:@"删除规则" message:[NSString stringWithFormat:@"确定删除 %@？", uri] preferredStyle:UIAlertControllerStyleAlert];
  [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  __weak typeof(self) weakSelf = self;
  [a addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
    weakSelf.setBusy(YES);
    [weakSelf.client shieldDeleteIds:@[@(sid)] completion:^(NSDictionary *data, NSError *error) {
      weakSelf.setBusy(NO);
      if (error) weakSelf.toast(error.localizedDescription);
      else [weakSelf reload];
    }];
  }]];
  UIResponder *r = self;
  UIViewController *vc = nil;
  while (r) {
    if ([r isKindOfClass:UIViewController.class]) { vc = (UIViewController *)r; break; }
    r = r.nextResponder;
  }
  [vc presentViewController:a animated:YES completion:nil];
}

@end
