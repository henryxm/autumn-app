#import "AutumnOpsCountChipBarView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsCountChipBarView ()
@property (nonatomic, strong) UIView *chipWrap;
@property (nonatomic, strong) UILabel *chipLabel;
@property (nonatomic, strong) UIButton *moreBtn;
@property (nonatomic, strong) UIView *spacer;
@end

@implementation AutumnOpsCountChipBarView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    // 对齐 Flutter OpsCountChipBar：Stadium 真胶囊；禁止横排 Fill 拉宽成豆荚。
    _chipWrap = [UIView new];
    _chipWrap.backgroundColor = [AutumnOpsUITheme.surfaceContainerHighest colorWithAlphaComponent:0.7];
    _chipWrap.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
      _chipWrap.layer.cornerCurve = kCACornerCurveCircular;
    }

    _chipLabel = [UILabel new];
    _chipLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _chipLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;
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
    [_moreBtn setTitleColor:AutumnOpsUITheme.primary forState:UIControlStateNormal];
    [_moreBtn addTarget:self action:@selector(_more) forControlEvents:UIControlEventTouchUpInside];
    _moreBtn.hidden = YES;
    [_moreBtn setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _spacer = [UIView new];
    [_spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_spacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                             forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ _chipWrap, _spacer, _moreBtn ]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.distribution = UIStackViewDistributionFill;
    [self addSubview:row];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [row.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
      [row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [row.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
    ]];
  }
  return self;
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
  // 仅 chip 固有高；宽由父级决定，chip 自身 hugging 不拉满
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
  self.moreBtn.hidden = !(hasMore && loaded > 0);
  self.moreBtn.enabled = !loadingMore;
  [self.moreBtn setTitle:loadingMore ? @"加载中…" : @"加载更多" forState:UIControlStateNormal];
  [self.chipWrap invalidateIntrinsicContentSize];
  [self setNeedsLayout];
}

- (void)_more {
  if (self.onLoadMore) self.onLoadMore();
}

@end
