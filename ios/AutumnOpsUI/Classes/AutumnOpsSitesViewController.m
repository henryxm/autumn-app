#import "AutumnOpsSitesViewController.h"
#import "AutumnOpsAddSiteViewController.h"
#import "AutumnOpsManageViewController.h"
#import "AutumnOpsPageChromeView.h"
#import "AutumnOpsSiteListCell.h"
#import "AutumnOpsUITheme.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>

static NSString * const kSiteCellId = @"AutumnOpsSiteListCell";

@interface AutumnOpsSitesViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) AutumnOpsSiteStore *siteStore;
@property (nonatomic, copy) NSArray<AutumnOpsSiteEntry *> *sites;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong, nullable) AutumnOpsPageChromeView *pageChrome;
@end

@implementation AutumnOpsSitesViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  self.title = @"Autumn 运维";
  self.siteStore = [[AutumnOpsSiteStore alloc] initWithRootDirectory:[AutumnOpsSiteStore defaultRootDirectory]];

  UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
  UIImageSymbolConfiguration *cfg =
      [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
  [add setImage:[UIImage systemImageNamed:@"plus" withConfiguration:cfg] forState:UIControlStateNormal];
  add.tintColor = UIColor.labelColor;
  add.accessibilityLabel = @"添加站点";
  [add addTarget:self action:@selector(_add) forControlEvents:UIControlEventTouchUpInside];
  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus" withConfiguration:cfg]
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(_add)];
  self.navigationItem.rightBarButtonItem.accessibilityLabel = @"添加站点";
  _pageChrome = [AutumnOpsPageChromeView installOnViewController:self title:@"Autumn 运维" rightItems:@[add]];

  _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  _tableView.dataSource = self;
  _tableView.delegate = self;
  _tableView.backgroundColor = UIColor.systemBackgroundColor;
  _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableView.rowHeight = UITableViewAutomaticDimension;
  _tableView.estimatedRowHeight = 96;
  _tableView.contentInset = UIEdgeInsetsMake(12, 0, 24, 0);
  [_tableView registerClass:[AutumnOpsSiteListCell class] forCellReuseIdentifier:kSiteCellId];
  [self.view addSubview:_tableView];

  _emptyLabel = [UILabel new];
  _emptyLabel.numberOfLines = 0;
  _emptyLabel.textAlignment = NSTextAlignmentCenter;
  _emptyLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;
  NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
  ps.lineHeightMultiple = 1.5;
  ps.alignment = NSTextAlignmentCenter;
  _emptyLabel.attributedText = [[NSAttributedString alloc] initWithString:
      @"还没有站点。\n点右上角「+」：① 首次口令 ② 认领码（文字）③ 导入运维凭证文件。"
      attributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:15],
        NSForegroundColorAttributeName : AutumnOpsUITheme.onSurfaceVariant,
        NSParagraphStyleAttributeName : ps,
      }];
  _emptyLabel.hidden = YES;
  [self.view addSubview:_emptyLabel];

  _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  _spinner.hidesWhenStopped = YES;
  [self.view addSubview:_spinner];

  [_tableView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.bottom.equalTo(self.view);
    if (_pageChrome) make.top.equalTo(_pageChrome.mas_bottom);
    else make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
  }];
  [_emptyLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.center.equalTo(self.tableView);
    make.left.right.equalTo(self.view).inset(24);
  }];
  [_spinner mas_makeConstraints:^(MASConstraintMaker *make) {
    make.center.equalTo(self.tableView);
  }];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  if (self.pageChrome) {
    self.pageChrome.showsBack = [AutumnOpsPageChromeView canGoBackFromViewController:self];
  }
  [self _reload];
}

- (void)_reload {
  [self.spinner startAnimating];
  self.emptyLabel.hidden = YES;
  self.tableView.hidden = YES;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSArray *list = [self.siteStore listSites:nil] ?: @[];
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.spinner stopAnimating];
      self.sites = list;
      BOOL empty = self.sites.count == 0;
      self.emptyLabel.hidden = !empty;
      self.tableView.hidden = empty;
      [self.tableView reloadData];
    });
  });
}

- (void)_add {
  [self.navigationController pushViewController:[[AutumnOpsAddSiteViewController alloc] initWithPresetBaseURL:nil autoProbe:NO] animated:YES];
}

- (void)_confirmDelete:(AutumnOpsSiteEntry *)site {
  NSString *name = site.title.length ? site.title : (site.baseUrl ?: @"");
  UIAlertController *a = [UIAlertController alertControllerWithTitle:@"删除站点"
                                                             message:[NSString stringWithFormat:@"从本机列表移除「%@」？不会自动吊销服务端证书。", name]
                                                      preferredStyle:UIAlertControllerStyleAlert];
  [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  __weak typeof(self) weakSelf = self;
  [a addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
    [weakSelf.siteStore removeSiteId:site.id error:nil];
    [weakSelf _reload];
  }]];
  [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.sites.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  AutumnOpsSiteListCell *cell = [tableView dequeueReusableCellWithIdentifier:kSiteCellId forIndexPath:indexPath];
  AutumnOpsSiteEntry *e = self.sites[indexPath.row];
  [cell configureWithSite:e];
  __weak typeof(self) weakSelf = self;
  cell.onDelete = ^{
    [weakSelf _confirmDelete:e];
  };
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  AutumnOpsSiteEntry *e = self.sites[indexPath.row];
  [self.navigationController pushViewController:[[AutumnOpsManageViewController alloc] initWithSiteEntry:e siteStore:self.siteStore] animated:YES];
}

@end
