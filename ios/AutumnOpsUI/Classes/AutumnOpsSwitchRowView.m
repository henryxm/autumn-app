#import "AutumnOpsSwitchRowView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsSwitchRowView ()
@property (nonatomic, strong, readwrite) UISwitch *switchControl;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@end

@implementation AutumnOpsSwitchRowView

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _titleLabel = [UILabel new];
    _titleLabel.text = title;
    _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _subtitleLabel = [UILabel new];
    _subtitleLabel.text = subtitle;
    _subtitleLabel.font = [UIFont systemFontOfSize:12];
    _subtitleLabel.numberOfLines = 0;
    UIStackView *left = [[UIStackView alloc] initWithArrangedSubviews:@[ _titleLabel, _subtitleLabel ]];
    left.axis = UILayoutConstraintAxisVertical;
    left.spacing = 2;
    _switchControl = [UISwitch new];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ left, _switchControl ]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 8;
    [left setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self addSubview:row];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [row.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
      [row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [row.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
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
  self.titleLabel.textColor = AutumnOpsUITheme.onSurface;
  self.subtitleLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;
  self.switchControl.onTintColor = AutumnOpsUITheme.primary;
}

@end
