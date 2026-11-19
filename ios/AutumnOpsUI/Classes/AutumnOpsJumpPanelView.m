#import "AutumnOpsJumpPanelView.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>

@interface AutumnOpsJumpPanelView () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) AutumnOpsClient *client;
@property (nonatomic, copy) AutumnOpsPanelToast toast;
@property (nonatomic, copy) AutumnOpsPanelBusy setBusy;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) UILabel *countChip;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@property (nonatomic) NSInteger totalCount;
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
    _rows = @[];
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

  UILabel *title = [UILabel new];
  title.text = @"防御跳转";
  title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
  UILabel *desc = [UILabel new];
  desc.text = @"按域名与资源匹配后跳转到目标地址，与盾牌分表互不影响。";
  desc.numberOfLines = 0;
  desc.font = [UIFont systemFontOfSize:13];
  desc.textColor = UIColor.secondaryLabelColor;
  UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
  [add setTitle:@"添加" forState:UIControlStateNormal];
  add.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  add.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.12];
  add.layer.cornerRadius = 10;
  add.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
  [add addTarget:self action:@selector(_add) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *headerRight = [[UIStackView alloc] initWithArrangedSubviews:@[add]];
  UIStackView *headerLeft = [[UIStackView alloc] initWithArrangedSubviews:@[title, desc]];
  headerLeft.axis = UILayoutConstraintAxisVertical;
  headerLeft.spacing = 4;
  UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[headerLeft, headerRight]];
  header.axis = UILayoutConstraintAxisHorizontal;
  header.alignment = UIStackViewAlignmentTop;
  header.spacing = 8;
  [headerLeft setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

  _countChip = [UILabel new];
  _countChip.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
  _countChip.textColor = UIColor.secondaryLabelColor;
  _countChip.backgroundColor = [UIColor.tertiarySystemFillColor colorWithAlphaComponent:0.9];
  _countChip.layer.cornerRadius = 10;
  _countChip.clipsToBounds = YES;
  _countChip.text = @"  暂无规则  ";

  _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  _table.dataSource = self;
  _table.delegate = self;
  _table.scrollEnabled = NO;
  _table.separatorStyle = UITableViewCellSeparatorStyleNone;
  _table.backgroundColor = UIColor.clearColor;
  [_table registerClass:UITableViewCell.class forCellReuseIdentifier:@"rule"];

  UIStackView *root = [[UIStackView alloc] initWithArrangedSubviews:@[header, _countChip, _table]];
  root.axis = UILayoutConstraintAxisVertical;
  root.spacing = 12;
  [_content addSubview:root];
  [root mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(_content).insets(UIEdgeInsetsMake(12, 16, 28, 16));
  }];
  [_table mas_makeConstraints:^(MASConstraintMaker *make) {
    make.height.mas_equalTo(1).priorityLow();
  }];
}

- (void)reload {
  self.setBusy(YES);
  [self.client jumpListPage:1 limit:100 completion:^(NSDictionary *page, NSError *error) {
    self.setBusy(NO);
    [self.scroll.refreshControl endRefreshing];
    if (error) {
      self.toast(error.localizedDescription);
      return;
    }
    NSArray *list = [page[@"list"] isKindOfClass:[NSArray class]] ? page[@"list"] : @[];
    NSMutableArray *rows = [NSMutableArray array];
    for (id o in list) if ([o isKindOfClass:[NSDictionary class]]) [rows addObject:o];
    self.rows = rows;
    self.totalCount = [page[@"count"] respondsToSelector:@selector(integerValue)] ? [page[@"count"] integerValue] : rows.count;
    self.countChip.text = self.totalCount <= 0 ? @"  暂无规则  " : [NSString stringWithFormat:@"  共 %ld 条  ", (long)self.totalCount];
    [self.table reloadData];
    [self.table layoutIfNeeded];
    CGFloat h = MAX(1, self.table.contentSize.height);
    [self.table mas_updateConstraints:^(MASConstraintMaker *make) {
      make.height.mas_equalTo(h);
    }];
  }];
}

- (void)_add {
  [self _edit:nil];
}

- (void)_edit:(NSDictionary *)existing {
  UIAlertController *a = [UIAlertController alertControllerWithTitle:existing ? @"编辑跳转" : @"添加跳转" message:nil preferredStyle:UIAlertControllerStyleAlert];
  [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = @"域名";
    tf.text = existing[@"host"] ? [NSString stringWithFormat:@"%@", existing[@"host"]] : @"";
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
  }];
  [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = @"资源路径";
    tf.text = existing[@"uri"] ? [NSString stringWithFormat:@"%@", existing[@"uri"]] : @"/";
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
  }];
  [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = @"跳转地址";
    tf.text = existing[@"url"] ? [NSString stringWithFormat:@"%@", existing[@"url"]] : @"";
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.keyboardType = UIKeyboardTypeURL;
  }];
  [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  __weak typeof(self) weakSelf = self;
  [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *host = [a.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *uri = [a.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *url = [a.textFields[2].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!host.length || !uri.length || !url.length) {
      weakSelf.toast(@"域名、资源路径、跳转地址均不能为空");
      return;
    }
    BOOL enable = existing ? [existing[@"enable"] boolValue] : YES;
    weakSelf.setBusy(YES);
    if (existing) {
      NSInteger jid = [existing[@"id"] integerValue];
      [weakSelf.client jumpUpdateId:jid host:host uri:uri url:url enable:@(enable) completion:^(NSDictionary *data, NSError *error) {
        weakSelf.setBusy(NO);
        if (error) weakSelf.toast(error.localizedDescription);
        else [weakSelf reload];
      }];
    } else {
      [weakSelf.client jumpSaveHost:host uri:uri url:url enable:YES completion:^(NSDictionary *data, NSError *error) {
        weakSelf.setBusy(NO);
        if (error) weakSelf.toast(error.localizedDescription);
        else [weakSelf reload];
      }];
    }
  }]];
  [[self _hostVC] presentViewController:a animated:YES completion:nil];
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
  NSString *host = [NSString stringWithFormat:@"%@", row[@"host"] ?: @""];
  NSString *uri = [NSString stringWithFormat:@"%@", row[@"uri"] ?: @""];
  NSString *url = [NSString stringWithFormat:@"%@", row[@"url"] ?: @""];

  UIView *card = [UIView new];
  card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
  card.layer.cornerRadius = 12;
  card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
  card.layer.borderColor = UIColor.separatorColor.CGColor;
  card.clipsToBounds = YES;
  UIView *bar = [UIView new];
  bar.backgroundColor = on ? UIColor.systemTealColor : UIColor.tertiaryLabelColor;
  UILabel *title = [UILabel new];
  title.text = [NSString stringWithFormat:@"%@%@", host, uri];
  title.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightSemibold];
  title.numberOfLines = 0;
  UILabel *sub = [UILabel new];
  sub.text = [NSString stringWithFormat:@"→ %@", url];
  sub.font = [UIFont systemFontOfSize:13];
  sub.textColor = UIColor.secondaryLabelColor;
  sub.numberOfLines = 0;
  UILabel *pill = [UILabel new];
  pill.text = on ? @"  已开启  " : @"  已关闭  ";
  pill.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
  pill.textColor = on ? UIColor.systemTealColor : UIColor.secondaryLabelColor;
  pill.backgroundColor = [UIColor.tertiarySystemFillColor colorWithAlphaComponent:0.8];
  pill.layer.cornerRadius = 10;
  pill.clipsToBounds = YES;
  UIButton *edit = [UIButton buttonWithType:UIButtonTypeSystem];
  [edit setTitle:@"编辑" forState:UIControlStateNormal];
  edit.tag = indexPath.row;
  [edit addTarget:self action:@selector(_editTap:) forControlEvents:UIControlEventTouchUpInside];
  UIButton *toggle = [UIButton buttonWithType:UIButtonTypeSystem];
  [toggle setTitle:on ? @"关闭" : @"开启" forState:UIControlStateNormal];
  toggle.tag = indexPath.row;
  [toggle addTarget:self action:@selector(_toggle:) forControlEvents:UIControlEventTouchUpInside];
  UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
  [del setTitle:@"删除" forState:UIControlStateNormal];
  [del setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
  del.tag = indexPath.row;
  [del addTarget:self action:@selector(_delete:) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[edit, toggle, del]];
  actions.axis = UILayoutConstraintAxisHorizontal;
  actions.spacing = 8;
  UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[title, pill]];
  top.axis = UILayoutConstraintAxisHorizontal;
  top.spacing = 6;
  top.alignment = UIStackViewAlignmentTop;
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

- (void)_editTap:(UIButton *)sender {
  [self _edit:self.rows[sender.tag]];
}

- (void)_toggle:(UIButton *)sender {
  NSDictionary *row = self.rows[sender.tag];
  NSInteger jid = [row[@"id"] integerValue];
  BOOL next = ![row[@"enable"] boolValue];
  self.setBusy(YES);
  [self.client jumpUpdateId:jid host:nil uri:nil url:nil enable:@(next) completion:^(NSDictionary *data, NSError *error) {
    self.setBusy(NO);
    if (error) self.toast(error.localizedDescription);
    else [self reload];
  }];
}

- (void)_delete:(UIButton *)sender {
  NSDictionary *row = self.rows[sender.tag];
  NSInteger jid = [row[@"id"] integerValue];
  NSString *name = [NSString stringWithFormat:@"%@%@", row[@"host"] ?: @"", row[@"uri"] ?: @""];
  UIAlertController *a = [UIAlertController alertControllerWithTitle:@"删除跳转" message:[NSString stringWithFormat:@"确定删除 %@？", name] preferredStyle:UIAlertControllerStyleAlert];
  [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  __weak typeof(self) weakSelf = self;
  [a addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
    weakSelf.setBusy(YES);
    [weakSelf.client jumpDeleteIds:@[@(jid)] completion:^(NSDictionary *data, NSError *error) {
      weakSelf.setBusy(NO);
      if (error) weakSelf.toast(error.localizedDescription);
      else [weakSelf reload];
    }];
  }]];
  [[self _hostVC] presentViewController:a animated:YES completion:nil];
}

@end
