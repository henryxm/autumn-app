#import "AutumnOpsAddSectionView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsAddSectionView ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UIStackView *contentStack;
@end

@implementation AutumnOpsAddSectionView

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.backgroundColor = [AutumnOpsUITheme.surfaceContainerHighest colorWithAlphaComponent:0.4];
    self.layer.cornerRadius = 14;
    self.clipsToBounds = YES;

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    _titleLabel.textColor = AutumnOpsUITheme.onSurface;
    _titleLabel.text = title;
    _titleLabel.numberOfLines = 1;

    _contentStack = [[UIStackView alloc] init];
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 10;
    _contentStack.alignment = UIStackViewAlignmentFill;

    NSMutableArray<UIView *> *parts = [NSMutableArray arrayWithObject:_titleLabel];
    BOOL hasSub = subtitle.length > 0;
    if (hasSub) {
      _subtitleLabel = [UILabel new];
      _subtitleLabel.numberOfLines = 0;
      NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
      ps.lineHeightMultiple = 1.4;
      _subtitleLabel.attributedText = [[NSAttributedString alloc] initWithString:subtitle
          attributes:@{
            NSFontAttributeName : [UIFont systemFontOfSize:12],
            NSForegroundColorAttributeName : AutumnOpsUITheme.onSurfaceVariant,
            NSParagraphStyleAttributeName : ps,
          }];
      [parts addObject:_subtitleLabel];
    }
    [parts addObject:_contentStack];

    UIStackView *root = [[UIStackView alloc] initWithArrangedSubviews:parts];
    root.axis = UILayoutConstraintAxisVertical;
    root.alignment = UIStackViewAlignmentFill;
    root.spacing = 4;
    UIView *beforeContent = hasSub ? _subtitleLabel : _titleLabel;
    [root setCustomSpacing:12 afterView:beforeContent];
    [self addSubview:root];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [root.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
      [root.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
      [root.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
      [root.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-14],
    ]];
  }
  return self;
}

@end
