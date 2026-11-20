#import "AutumnOpsPageChromeView.h"

@interface AutumnOpsPageChromeView ()
@property (nonatomic, strong) UIButton *backBtn;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIStackView *rightStack;
@property (nonatomic, strong) UIView *hairline;
@end

@implementation AutumnOpsPageChromeView

+ (BOOL)shouldEmbedInViewController:(UIViewController *)vc {
  UINavigationController *nav = vc.navigationController;
  if (!nav) return YES;
  if (nav.navigationBarHidden) return YES;
  if (nav.navigationBar.hidden) return YES;
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

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.backgroundColor = UIColor.systemBackgroundColor;
    _showsBack = YES;

    _backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *chev = [UIImage systemImageNamed:@"chevron.left"];
    [_backBtn setImage:chev forState:UIControlStateNormal];
    _backBtn.tintColor = UIColor.labelColor;
    [_backBtn addTarget:self action:@selector(_backTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_backBtn];

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self addSubview:_titleLabel];

    _rightStack = [[UIStackView alloc] init];
    _rightStack.axis = UILayoutConstraintAxisHorizontal;
    _rightStack.alignment = UIStackViewAlignmentCenter;
    _rightStack.spacing = 4;
    [self addSubview:_rightStack];

    _hairline = [UIView new];
    _hairline.backgroundColor = UIColor.separatorColor;
    [self addSubview:_hairline];
  }
  return self;
}

- (void)setTitleText:(NSString *)titleText {
  _titleText = [titleText copy];
  self.titleLabel.text = titleText;
}

- (void)setShowsBack:(BOOL)showsBack {
  _showsBack = showsBack;
  self.backBtn.hidden = !showsBack;
  [self setNeedsLayout];
}

- (void)_backTapped {
  if (self.onBack) self.onBack();
}

- (CGSize)intrinsicContentSize {
  return CGSizeMake(UIViewNoIntrinsicMetric, 44);
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat w = CGRectGetWidth(self.bounds);
  CGFloat h = CGRectGetHeight(self.bounds);
  CGFloat side = 44;
  CGFloat y = 0;
  CGFloat contentH = h - 1.0 / UIScreen.mainScreen.scale;

  self.backBtn.frame = CGRectMake(4, y, side, contentH);
  self.backBtn.hidden = !self.showsBack;

  [self.rightStack sizeToFit];
  CGFloat rightW = MAX(CGRectGetWidth(self.rightStack.bounds), 8);
  // Cap right stack width so title keeps room
  rightW = MIN(rightW, w * 0.42);
  self.rightStack.frame = CGRectMake(w - rightW - 8, y, rightW, contentH);

  CGFloat leftEdge = self.showsBack ? side : 12;
  CGFloat titleW = w - leftEdge - rightW - 16;
  self.titleLabel.frame = CGRectMake(leftEdge, y, MAX(0, titleW), contentH);

  CGFloat hair = 1.0 / UIScreen.mainScreen.scale;
  self.hairline.frame = CGRectMake(0, h - hair, w, hair);
}

@end
