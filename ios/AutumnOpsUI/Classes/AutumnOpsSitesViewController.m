#import "AutumnOpsSitesViewController.h"
#import "AutumnOpsAddSiteViewController.h"
#import "AutumnOpsManageViewController.h"
#import "AutumnOpsPageChromeView.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>

@interface AutumnOpsSitesViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) AutumnOpsSiteStore *siteStore;
@property (nonatomic, copy) NSArray<AutumnOpsSiteEntry *> *sites;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong, nullable) AutumnOpsPageChromeView *pageChrome;
@end

@implementation AutumnOpsSitesViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  self.title = @"Autumn 运维";
  self.siteStore = [[AutumnOpsSiteStore alloc] initWithRootDirectory:[AutumnOpsSiteStore defaultRootDirectory]];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(_add)];

  BOOL embed = [AutumnOpsPageChromeView shouldEmbedInViewController:self];
  UIView *top = nil;
  if (embed) {
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = nil;
    _pageChrome = [AutumnOpsPageChromeView new];
    _pageChrome.titleText = @"Autumn 运维";
    _pageChrome.showsBack = YES;
    __weak typeof(self) weakSelf = self;
    _pageChrome.onBack = ^{ [AutumnOpsPageChromeView performBackFromViewController:weakSelf]; };
    UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
    [add setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
    add.tintColor = UIColor.labelColor;
    [add addTarget:self action:@selector(_add) forControlEvents:UIControlEventTouchUpInside];
    [_pageChrome.rightStack addArrangedSubview:add];
    [self.view addSubview:_pageChrome];
    [_pageChrome mas_makeConstraints:^(MASConstraintMaker *make) {
      make.left.right.equalTo(self.view);
      make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
      make.height.mas_equalTo(44);
    }];
    top = _pageChrome;
  }

  _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
  _tableView.dataSource = self;
  _tableView.delegate = self;
  [self.view addSubview:_tableView];
  [_tableView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.bottom.equalTo(self.view);
    if (top) make.top.equalTo(top.mas_bottom);
    else make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
  }];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.sites = [self.siteStore listSites:nil];
  [self.tableView reloadData];
}

- (void)_add {
  [self.navigationController pushViewController:[[AutumnOpsAddSiteViewController alloc] initWithPresetBaseURL:nil autoProbe:NO] animated:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.sites.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"c"];
  if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
  AutumnOpsSiteEntry *e = self.sites[indexPath.row];
  cell.textLabel.text = e.title.length ? e.title : e.baseUrl;
  cell.detailTextLabel.numberOfLines = 2;
  cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@", e.baseUrl, e.enrolled ? @"已入驻" : @"未入驻"];
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  AutumnOpsSiteEntry *e = self.sites[indexPath.row];
  [self.navigationController pushViewController:[[AutumnOpsManageViewController alloc] initWithSiteEntry:e siteStore:self.siteStore] animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
  __weak typeof(self) weakSelf = self;
  UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"移除" handler:^(__kindof UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
    NSMutableArray *arr = [weakSelf.sites mutableCopy];
    AutumnOpsSiteEntry *e = arr[indexPath.row];
    [weakSelf.siteStore removeSiteId:e.id error:nil];
    [arr removeObjectAtIndex:indexPath.row];
    weakSelf.sites = arr;
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    completionHandler(YES);
  }];
  return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

@end
