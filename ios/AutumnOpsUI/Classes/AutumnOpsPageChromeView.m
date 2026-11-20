#import "AutumnOpsPageChromeView.h"
#import <Masonry/Masonry.h>

@interface AutumnOpsPageChromeView ()
@property (nonatomic, strong) UIButton *backBtn;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UIStackView *rightStack;
@property (nonatomic, strong) UIView *hairline;
@property (nonatomic, strong) MASConstraint *backWidthConstraint;
@end

@implementation AutumnOpsPageChromeView

+ (BOOL)shouldEmbedInViewController:(UIViewController *)vc {
  UINavigationController *nav = vc.navigationController;
  if (!nav) return YES;
  if (nav.navigationBarHidden) return YES;
  if (nav.navigationBar.hidden) return YES;
  return NO;
}

+ (BOOL)canGoBackFromViewController:(UIViewController *)vc {
  UINavigationController *nav = vc.navigationController;
  if (nav && nav.viewControllers.count > 1) return YES;
  if (vc.presentingViewController) return YES;
  if (nav.presentingViewController) return YES;
  return NO;
}

+ (void)performBackFromViewController:(UIViewController *)vc {
  UINavigationController *nav = vc.navigationController;
  if (nav && nav.viewControllers.count > 1) {
    [nav popViewControllerAnimated:YES];
    return;
  }
  if (vc.presentingViewController) {
    [vc dismissViewControllerAnimated:YES completion:nil];
    return;
  }
  if (nav.presentingViewController) {
    [nav dismissViewControllerAnimated:YES completion:nil];
  }
}

+ (AutumnOpsPageChromeView *)installOnViewController:(UIViewController *)vc
                                               title:(NSString *)title
                                          rightItems:(NSArray<UIView *> *)rightItems {
  if (![self shouldEmbedInViewController:vc]) return nil;
  vc.navigationItem.title = nil;
  vc.navigationItem.leftBarButtonItem = nil;
  vc.navigationItem.rightBarButtonItems = nil;
  AutumnOpsPageChromeView *chrome = [AutumnOpsPageChromeView new];
  chrome.titleText = title;
  chrome.showsBack = [self canGoBackFromViewController:vc];
  __weak UIViewController *weakVC = vc;
  chrome.onBack = ^{ [AutumnOpsPageChromeView performBackFromViewController:weakVC]; };
  for (UIView *item in rightItems ?: @[]) {
    [chrome addRightItem:item];
  }
  // 对齐 Flutter AppBar：顶栏同色铺进状态栏，避免 safeArea 上方露出卡片/异色底
  [vc.view addSubview:chrome];
  [chrome mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.right.top.equalTo(vc.view);
    make.bottom.equalTo(vc.view.mas_safeAreaLayoutGuideTop).offset(44);
  }];
  return chrome;
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    // 跟随宿主主题（XSVideo 等），勿用运维卡片色
    self.backgroundColor = UIColor.systemBackgroundColor;
    _showsBack = YES;

    _backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *chevCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
    [_backBtn setImage:[UIImage systemImageNamed:@"chevron.left" withConfiguration:chevCfg]
              forState:UIControlStateNormal];
    _backBtn.tintColor = UIColor.labelColor;
    _backBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [_backBtn addTarget:self action:@selector(_backTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_backBtn];

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _titleLabel.textColor = UIColor.labelColor;
    [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                  forAxis:UILayoutConstraintAxisHorizontal];
    [_titleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow
                                   forAxis:UILayoutConstraintAxisHorizontal];
    [self addSubview:_titleLabel];

    // 右侧按固有尺寸排布，禁止 Fill 拉伸把图标扭扁
    _rightStack = [[UIStackView alloc] init];
    _rightStack.axis = UILayoutConstraintAxisHorizontal;
    _rightStack.alignment = UIStackViewAlignmentCenter;
    _rightStack.distribution = UIStackViewDistributionFill;
    _rightStack.spacing = 0;
    [_rightStack setContentHuggingPriority:UILayoutPriorityRequired
                                   forAxis:UILayoutConstraintAxisHorizontal];
    [_rightStack setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                 forAxis:UILayoutConstraintAxisHorizontal];
    [self addSubview:_rightStack];

    _hairline = [UIView new];
    _hairline.backgroundColor = UIColor.separatorColor;
    [self addSubview:_hairline];

    // 控件落在底部 44pt 标题带；上方留给状态栏同色填充
    [_backBtn mas_makeConstraints:^(MASConstraintMaker *make) {
      make.leading.equalTo(self).offset(4);
      make.bottom.equalTo(self);
      make.height.mas_equalTo(44);
      self.backWidthConstraint = make.width.mas_equalTo(44);
    }];
    [_rightStack mas_makeConstraints:^(MASConstraintMaker *make) {
      make.trailing.equalTo(self).offset(-4);
      make.bottom.equalTo(self);
      make.height.mas_equalTo(44);
    }];
    // 相对标题带水平居中；左右夹紧避免与返回/右侧图标重叠
    [_titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
      make.centerX.equalTo(self);
      make.centerY.equalTo(self.backBtn);
      make.leading.greaterThanOrEqualTo(self.backBtn.mas_trailing).offset(4);
      make.trailing.lessThanOrEqualTo(self.rightStack.mas_leading).offset(-8);
    }];
    [_hairline mas_makeConstraints:^(MASConstraintMaker *make) {
      make.left.right.bottom.equalTo(self);
      make.height.mas_equalTo(1.0 / UIScreen.mainScreen.scale);
    }];
  }
  return self;
}

- (void)addRightItem:(UIView *)item {
  if (!item) return;
  [item setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [item setContentCompressionResistancePriority:UILayoutPriorityRequired
                                        forAxis:UILayoutConstraintAxisHorizontal];
  if ([item isKindOfClass:[UIButton class]]) {
    UIButton *btn = (UIButton *)item;
    btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    // 纯图标按钮固定 44×44，避免被 stack 拉扁
    if (btn.currentTitle.length == 0 && btn.currentImage != nil) {
      [btn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(44);
      }];
    } else {
      // 文字按钮：左右内边距，高度跟栏对齐
      btn.contentEdgeInsets = UIEdgeInsetsMake(8, 10, 8, 10);
      [btn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(44);
      }];
    }
  }
  [self.rightStack addArrangedSubview:item];
}

- (void)setTitleText:(NSString *)titleText {
  _titleText = [titleText copy];
  self.titleLabel.text = titleText;
}

- (void)setShowsBack:(BOOL)showsBack {
  _showsBack = showsBack;
  self.backBtn.hidden = !showsBack;
  self.backBtn.userInteractionEnabled = showsBack;
  [self.backBtn mas_updateConstraints:^(MASConstraintMaker *make) {
    make.width.mas_equalTo(showsBack ? 44 : 0);
  }];
}

- (void)_backTapped {
  if (self.onBack) self.onBack();
}

- (CGSize)intrinsicContentSize {
  return CGSizeMake(UIViewNoIntrinsicMetric, 44);
}

@end
