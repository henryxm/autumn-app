#import "AutumnOpsSectionCardView.h"

@interface AutumnOpsSectionCardView ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) CALayer *borderLayer;
@end

@implementation AutumnOpsSectionCardView

- (instancetype)initWithTitle:(NSString *)title body:(NSString *)body {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.backgroundColor = [UIColor.secondarySystemFillColor colorWithAlphaComponent:0.55];
    self.layer.cornerRadius = 14;
    self.clipsToBounds = YES;

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    _titleLabel.text = title;
    _titleLabel.numberOfLines = 1;

    _bodyLabel = [UILabel new];
    _bodyLabel.font = [UIFont systemFontOfSize:13];
    _bodyLabel.textColor = UIColor.secondaryLabelColor;
    _bodyLabel.numberOfLines = 0;
    _bodyLabel.text = body;

    _contentStack = [[UIStackView alloc] init];
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 0;
    _contentStack.alignment = UIStackViewAlignmentFill;

    UIStackView *root = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _bodyLabel, _contentStack]];
    root.axis = UILayoutConstraintAxisVertical;
    root.spacing = 6;
    root.alignment = UIStackViewAlignmentFill;
    [root setCustomSpacing:12 afterView:_bodyLabel];
    [self addSubview:root];

    root.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [root.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
      [root.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
      [root.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
      [root.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-16],
    ]];
  }
  return self;
}

- (void)setBodyText:(NSString *)body {
  self.bodyLabel.text = body;
}

- (void)setOutlined:(BOOL)outlined {
  if (outlined) {
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.8].CGColor;
  } else {
    self.layer.borderWidth = 0;
  }
}

+ (UIView *)kvRowWithKey:(NSString *)key value:(NSString *)value {
  UIView *row = [UIView new];
  UILabel *k = [UILabel new];
  k.text = key;
  k.font = [UIFont systemFontOfSize:13];
  k.textColor = UIColor.secondaryLabelColor;
  UILabel *v = [UILabel new];
  v.text = value;
  v.font = [UIFont systemFontOfSize:13];
  v.numberOfLines = 0;
  v.textAlignment = NSTextAlignmentLeft;
  [row addSubview:k];
  [row addSubview:v];
  k.translatesAutoresizingMaskIntoConstraints = NO;
  v.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [k.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
    [k.topAnchor constraintEqualToAnchor:row.topAnchor],
    [k.widthAnchor constraintEqualToConstant:96],
    [k.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor constant:-8],
    [v.leadingAnchor constraintEqualToAnchor:k.trailingAnchor],
    [v.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
    [v.topAnchor constraintEqualToAnchor:row.topAnchor],
    [v.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-8],
  ]];
  return row;
}

+ (UILabel *)statusChipWithText:(NSString *)text on:(BOOL)on {
  UILabel *chip = [UILabel new];
  chip.text = [NSString stringWithFormat:@"  %@  ", text];
  chip.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
  chip.textAlignment = NSTextAlignmentCenter;
  chip.layer.cornerRadius = 14;
  chip.clipsToBounds = YES;
  if (on) {
    chip.backgroundColor = [UIColor.systemTealColor colorWithAlphaComponent:0.22];
    chip.textColor = UIColor.labelColor;
  } else {
    chip.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.18];
    chip.textColor = UIColor.labelColor;
  }
  [chip setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [chip setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  return chip;
}

@end
