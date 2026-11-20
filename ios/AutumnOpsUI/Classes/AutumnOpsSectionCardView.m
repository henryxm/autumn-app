#import "AutumnOpsSectionCardView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsSectionCardView ()
@property (nonatomic, strong) UIStackView *titleRow;
@property (nonatomic, strong) UIView *titleLeadingSlot;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *titleAccessorySlot;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic) BOOL outlined;
@end

@implementation AutumnOpsSectionCardView

- (instancetype)initWithTitle:(NSString *)title body:(NSString *)body {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.backgroundColor = AutumnOpsUITheme.cardFill;
    self.layer.cornerRadius = 14;
    self.clipsToBounds = YES;

    _titleLeadingSlot = [UIView new];
    _titleLeadingSlot.hidden = YES;
    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    _titleLabel.textColor = AutumnOpsUITheme.onSurface;
    _titleLabel.text = title;
    _titleLabel.numberOfLines = 1;
    _titleAccessorySlot = [UIView new];
    _titleAccessorySlot.hidden = YES;

    _titleRow = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLeadingSlot, _titleLabel, _titleAccessorySlot]];
    _titleRow.axis = UILayoutConstraintAxisHorizontal;
    _titleRow.alignment = UIStackViewAlignmentCenter;
    _titleRow.spacing = 8;
    [_titleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    _bodyLabel = [UILabel new];
    _bodyLabel.numberOfLines = 0;
    // Flutter body：13 / height 1.45 / onSurfaceVariant
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.lineHeightMultiple = 1.45;
    _bodyLabel.attributedText = [[NSAttributedString alloc] initWithString:body ?: @""
        attributes:@{
          NSFontAttributeName : [UIFont systemFontOfSize:13],
          NSForegroundColorAttributeName : AutumnOpsUITheme.onSurfaceVariant,
          NSParagraphStyleAttributeName : ps,
        }];

    _contentStack = [[UIStackView alloc] init];
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 0;
    _contentStack.alignment = UIStackViewAlignmentFill;

    UIStackView *root = [[UIStackView alloc] initWithArrangedSubviews:@[_titleRow, _bodyLabel, _contentStack]];
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
  NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
  ps.lineHeightMultiple = 1.45;
  self.bodyLabel.attributedText = [[NSAttributedString alloc] initWithString:body ?: @""
      attributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:13],
        NSForegroundColorAttributeName : AutumnOpsUITheme.onSurfaceVariant,
        NSParagraphStyleAttributeName : ps,
      }];
}

- (void)setOutlined:(BOOL)outlined {
  _outlined = outlined;
  if (outlined) {
    [AutumnOpsUITheme applyBorderToLayer:self.layer color:AutumnOpsUITheme.outlineVariantBorder width:1];
  } else {
    self.layer.borderWidth = 0;
  }
}

- (void)setTitleLeading:(UIView *)leading {
  for (UIView *v in self.titleLeadingSlot.subviews) [v removeFromSuperview];
  if (!leading) {
    self.titleLeadingSlot.hidden = YES;
    return;
  }
  self.titleLeadingSlot.hidden = NO;
  [self.titleLeadingSlot addSubview:leading];
  leading.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [leading.leadingAnchor constraintEqualToAnchor:self.titleLeadingSlot.leadingAnchor],
    [leading.trailingAnchor constraintEqualToAnchor:self.titleLeadingSlot.trailingAnchor],
    [leading.topAnchor constraintEqualToAnchor:self.titleLeadingSlot.topAnchor],
    [leading.bottomAnchor constraintEqualToAnchor:self.titleLeadingSlot.bottomAnchor],
    [leading.widthAnchor constraintEqualToConstant:20],
    [leading.heightAnchor constraintEqualToConstant:20],
  ]];
}

- (void)setTitleAccessory:(UIView *)accessory {
  for (UIView *v in self.titleAccessorySlot.subviews) [v removeFromSuperview];
  if (!accessory) {
    self.titleAccessorySlot.hidden = YES;
    return;
  }
  self.titleAccessorySlot.hidden = NO;
  [self.titleAccessorySlot setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [self.titleAccessorySlot setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [self.titleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [self.titleRow setCustomSpacing:8 afterView:self.titleLabel];
  [self.titleAccessorySlot addSubview:accessory];
  accessory.translatesAutoresizingMaskIntoConstraints = NO;
  // 槽宽跟配件固有宽度走，避免标题行把 chip 背景横向撑开
  [NSLayoutConstraint activateConstraints:@[
    [accessory.leadingAnchor constraintEqualToAnchor:self.titleAccessorySlot.leadingAnchor],
    [accessory.trailingAnchor constraintEqualToAnchor:self.titleAccessorySlot.trailingAnchor],
    [accessory.topAnchor constraintEqualToAnchor:self.titleAccessorySlot.topAnchor],
    [accessory.bottomAnchor constraintEqualToAnchor:self.titleAccessorySlot.bottomAnchor],
  ]];
}

+ (UIView *)kvRowWithKey:(NSString *)key value:(NSString *)value {
  UIView *row = [UIView new];
  UILabel *k = [UILabel new];
  k.text = key;
  k.font = [UIFont systemFontOfSize:13];
  k.textColor = AutumnOpsUITheme.onSurfaceVariant;
  UILabel *v = [UILabel new];
  v.text = value;
  v.font = [UIFont systemFontOfSize:13];
  v.textColor = AutumnOpsUITheme.onSurface;
  v.numberOfLines = 0;
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

@end
