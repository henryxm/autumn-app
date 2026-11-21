#import "AutumnOpsCountChipBarView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsCountChipBarView ()
@property (nonatomic, strong) UIStackView *row;
@property (nonatomic, strong) UIView *chipWrap;
@property (nonatomic, strong) UILabel *chipLabel;
@property (nonatomic, strong) UIButton *moreBtn;
@property (nonatomic, strong) UIView *spacer;
@property (nonatomic, strong, nullable) UIView *installedTrailing;
@property (nonatomic) BOOL showMore;
@end

@implementation AutumnOpsCountChipBarView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    // 对齐 Flutter OpsCountChipBar：Stadium 真胶囊；禁止横排 Fill 拉宽成豆荚。
    _chipWrap = [UIView new];
    _chipWrap.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
      _chipWrap.layer.cornerCurve = kCACornerCurveCircular;
    }

    _chipLabel = [UILabel new];
    _chipLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _chipLabel.numberOfLines = 1;
    [_chipWrap addSubview:_chipLabel];
    _chipLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_chipLabel.topAnchor constraintEqualToAnchor:_chipWrap.topAnchor constant:4],
      [_chipLabel.bottomAnchor constraintEqualToAnchor:_chipWrap.bottomAnchor constant:-4],
      [_chipLabel.leadingAnchor constraintEqualToAnchor:_chipWrap.leadingAnchor constant:10],
      [_chipLabel.trailingAnchor constraintEqualToAnchor:_chipWrap.trailingAnchor constant:-10],
    ]];
    [_chipWrap setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_chipWrap setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [_chipWrap setContentCompressionResistancePriority:UILayoutPriorityRequired
                                               forAxis:UILayoutConstraintAxisHorizontal];
    [_chipLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _moreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_moreBtn setTitle:@"加载更多" forState:UIControlStateNormal];
    _moreBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [_moreBtn addTarget:self action:@selector(_more) forControlEvents:UIControlEventTouchUpInside];
    _moreBtn.hidden = YES;
    [_moreBtn setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _spacer = [UIView new];
    [_spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_spacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                             forAxis:UILayoutConstraintAxisHorizontal];

    _row = [[UIStackView alloc] initWithArrangedSubviews:@[ _chipWrap, _spacer, _moreBtn ]];
    _row.axis = UILayoutConstraintAxisHorizontal;
    _row.alignment = UIStackViewAlignmentCenter;
    _row.distribution = UIStackViewDistributionFill;
    [self addSubview:_row];
    _row.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_row.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
      [_row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [_row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [_row.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
    ]];
    [self _applyThemeColors];
  }
  return self;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  if (@available(iOS 13.0, *)) {
    if (![self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) return;
  }
  [self _applyThemeColors];
}

- (void)_applyThemeColors {
  self.chipWrap.backgroundColor = [AutumnOpsUITheme.surfaceContainerHighest colorWithAlphaComponent:0.7];
  self.chipLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;
  [self.moreBtn setTitleColor:AutumnOpsUITheme.primary forState:UIControlStateNormal];
}

- (void)setTrailingView:(UIView *)trailingView {
  if (_installedTrailing) {
    [_row removeArrangedSubview:_installedTrailing];
    [_installedTrailing removeFromSuperview];
    _installedTrailing = nil;
  }
  _trailingView = trailingView;
  if (trailingView) {
    [trailingView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [trailingView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                  forAxis:UILayoutConstraintAxisHorizontal];
    [_row addArrangedSubview:trailingView];
    _installedTrailing = trailingView;
  }
  [self _syncRightVisibility];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat h = CGRectGetHeight(self.chipWrap.bounds);
  self.chipWrap.layer.cornerRadius = h > 0.5 ? (h * 0.5) : 10;
}

- (CGSize)intrinsicContentSize {
  CGSize s = [self.chipLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
  if (s.width < 1 && self.chipLabel.text.length) {
    s = [self.chipLabel.text sizeWithAttributes:@{ NSFontAttributeName : self.chipLabel.font }];
  }
  return CGSizeMake(UIViewNoIntrinsicMetric, ceil(MAX(s.height, 12)) + 4 + 4 + 8);
}

- (void)configureLoaded:(NSInteger)loaded
                  total:(NSInteger)total
                hasMore:(BOOL)hasMore
            loadingMore:(BOOL)loadingMore
             emptyLabel:(NSString *)emptyLabel {
  NSString *text;
  if (total <= 0) text = emptyLabel.length ? emptyLabel : @"暂无记录";
  else if (loaded >= total) text = [NSString stringWithFormat:@"共 %ld 条", (long)total];
  else text = [NSString stringWithFormat:@"已加载 %ld / 共 %ld", (long)loaded, (long)total];
  self.chipLabel.text = text;
  self.showMore = hasMore && loaded > 0;
  self.moreBtn.enabled = !loadingMore;
  [self.moreBtn setTitle:loadingMore ? @"加载中…" : @"加载更多" forState:UIControlStateNormal];
  [self _syncRightVisibility];
  [self.chipWrap invalidateIntrinsicContentSize];
  [self setNeedsLayout];
}

- (void)_syncRightVisibility {
  if (self.trailingView) {
    self.moreBtn.hidden = YES;
    self.trailingView.hidden = NO;
  } else {
    self.moreBtn.hidden = !self.showMore;
  }
}

- (void)_more {
  if (self.onLoadMore) self.onLoadMore();
}

@end
