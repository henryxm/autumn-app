#import "AutumnOpsSitesViewController.h"
#import "AutumnOpsAddSiteViewController.h"
#import "AutumnOpsManageViewController.h"
#import <AutumnOpsCore/AutumnOpsCore.h>

@interface AutumnOpsSitesViewController ()
@property (nonatomic, strong) AutumnOpsSiteStore *siteStore;
@property (nonatomic, copy) NSArray<AutumnOpsSiteEntry *> *sites;
@end

@implementation AutumnOpsSitesViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = @"运维站点";
  self.siteStore = [[AutumnOpsSiteStore alloc] initWithRootDirectory:[AutumnOpsSiteStore defaultRootDirectory]];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(_add)];
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
