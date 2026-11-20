#import "AutumnOpsMetaChipView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsMetaChipView ()
@property (nonatomic, strong) UILabel *label;
@end

@implementation AutumnOpsMetaChipView

- (instancetype)initWithText:(NSString *)text {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    // Flutter OpsMetaChip：pad H7/V2、radius 6、primaryContainer@0.4、primary 字
    self.layer.cornerRadius = 6;
    self.clipsToBounds = YES;
    self.backgroundColor = [AutumnOpsUITheme.primaryContainer colorWithAlphaComponent:0.4];
    _label = [UILabel new];
    _label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    _label.textColor = AutumnOpsUITheme.primary;
    _label.numberOfLines = 1;
    [self addSubview:_label];
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_label.topAnchor constraintEqualToAnchor:self.topAnchor constant:2],
      [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2],
      [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:7],
      [_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-7],
    ]];
    [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self setText:text];
  }
  return self;
}

- (CGSize)intrinsicContentSize {
  CGSize s = [self.label sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
  if (s.width < 1 && self.label.text.length) {
    s = [self.label.text sizeWithAttributes:@{ NSFontAttributeName : self.label.font }];
  }
  return CGSizeMake(ceil(s.width) + 14, ceil(s.height) + 4);
}

- (void)setText:(NSString *)text {
  self.label.text = text;
  [self invalidateIntrinsicContentSize];
}

@end
