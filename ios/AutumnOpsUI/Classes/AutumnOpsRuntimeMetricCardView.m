#import "AutumnOpsRuntimeMetricCardView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsRuntimeMetricCardView ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UIStackView *contentStack;
@end

@implementation AutumnOpsRuntimeMetricCardView

- (instancetype)initWithTitle:(NSString *)title {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.backgroundColor = [AutumnOpsUITheme.surfaceContainerHighest colorWithAlphaComponent:0.55];
    self.layer.cornerRadius = 12;
    self.clipsToBounds = YES;

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    _titleLabel.textColor = AutumnOpsUITheme.onSurface;
    _titleLabel.text = title;

    _contentStack = [[UIStackView alloc] init];
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 0;
    _contentStack.alignment = UIStackViewAlignmentFill;

    UIStackView *root = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _contentStack]];
    root.axis = UILayoutConstraintAxisVertical;
    root.alignment = UIStackViewAlignmentFill;
    root.spacing = 10;
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

- (void)clearContent {
  for (UIView *v in [self.contentStack.arrangedSubviews copy]) {
    [self.contentStack removeArrangedSubview:v];
    [v removeFromSuperview];
  }
}

- (void)setNAReason:(NSString *)reason {
  [self clearContent];
  UILabel *l = [UILabel new];
  l.numberOfLines = 0;
  l.font = [UIFont systemFontOfSize:13];
  l.textColor = AutumnOpsUITheme.onSurfaceVariant;
  l.text = reason.length ? reason : @"暂无";
  [self.contentStack addArrangedSubview:l];
}

@end
