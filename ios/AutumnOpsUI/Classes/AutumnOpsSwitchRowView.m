#import "AutumnOpsSwitchRowView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsSwitchRowView ()
@property (nonatomic, strong, readwrite) UISwitch *switchControl;
@end

@implementation AutumnOpsSwitchRowView

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    UILabel *t = [UILabel new];
    t.text = title;
    t.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    t.textColor = AutumnOpsUITheme.onSurface;
    UILabel *s = [UILabel new];
    s.text = subtitle;
    s.font = [UIFont systemFontOfSize:12];
    s.textColor = AutumnOpsUITheme.onSurfaceVariant;
    s.numberOfLines = 0;
    UIStackView *left = [[UIStackView alloc] initWithArrangedSubviews:@[t, s]];
    left.axis = UILayoutConstraintAxisVertical;
    left.spacing = 2;
    _switchControl = [UISwitch new];
    _switchControl.onTintColor = AutumnOpsUITheme.primary;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[left, _switchControl]];
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
  }
  return self;
}

@end
