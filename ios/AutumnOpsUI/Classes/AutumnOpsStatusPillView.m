#import "AutumnOpsStatusPillView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsStatusPillView ()
@property (nonatomic, strong) UIView *dot;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIStackView *row;
@end

@implementation AutumnOpsStatusPillView

- (instancetype)initWithLabel:(NSString *)label active:(BOOL)active {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    // Flutter OpsStatusPill：H8/V3 + BorderRadius.circular(20) → 短高时即为半高胶囊，禁止被 Stack 拉成橄榄球。
    self.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
      self.layer.cornerCurve = kCACornerCurveCircular;
    }
    _dot = [UIView new];
    _dot.layer.cornerRadius = 3;
    _dot.clipsToBounds = YES;
    _label = [UILabel new];
    _label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    _label.numberOfLines = 1;
    _label.lineBreakMode = NSLineBreakByClipping;
    _row = [[UIStackView alloc] initWithArrangedSubviews:@[ _dot, _label ]];
    _row.axis = UILayoutConstraintAxisHorizontal;
    _row.spacing = 5;
    _row.alignment = UIStackViewAlignmentCenter;
    _row.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_row];
    [_dot.widthAnchor constraintEqualToConstant:6].active = YES;
    [_dot.heightAnchor constraintEqualToConstant:6].active = YES;
    [NSLayoutConstraint activateConstraints:@[
      [_row.topAnchor constraintEqualToAnchor:self.topAnchor constant:3],
      [_row.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-3],
      [_row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
      [_row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
    ]];
    [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [_label setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self setLabel:label active:active];
  }
  return self;
}

- (CGSize)intrinsicContentSize {
  CGSize s = [self.label sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
  if (s.width < 1 && self.label.text.length) {
    s = [self.label.text sizeWithAttributes:@{ NSFontAttributeName : self.label.font }];
  }
  // pad H8×2 + dot 6 + spacing 5；高 ≈ 文案 + V3×2（与 Flutter 一致）
  CGFloat w = ceil(s.width) + 8 + 8 + 6 + 5;
  CGFloat h = ceil(MAX(s.height, 6)) + 3 + 3;
  return CGSizeMake(w, h);
}

- (void)layoutSubviews {
  [super layoutSubviews];
  // 半高圆角 = 真胶囊；固定 20 在被误拉宽时会呈橄榄球两端。
  CGFloat h = CGRectGetHeight(self.bounds);
  self.layer.cornerRadius = h > 0.5 ? (h * 0.5) : 10;
}

- (CGSize)sizeThatFits:(CGSize)size {
  return [self intrinsicContentSize];
}

- (void)setLabel:(NSString *)label active:(BOOL)active {
  self.label.text = label;
  self.label.textColor = active ? AutumnOpsUITheme.onTertiaryContainer : AutumnOpsUITheme.onSurfaceVariant;
  self.backgroundColor = active
      ? [AutumnOpsUITheme.tertiaryContainer colorWithAlphaComponent:0.55]
      : [AutumnOpsUITheme.surfaceContainerHighest colorWithAlphaComponent:0.9];
  self.dot.backgroundColor = active ? AutumnOpsUITheme.tertiary : AutumnOpsUITheme.outline;
  [self invalidateIntrinsicContentSize];
  [self setNeedsLayout];
}

@end
