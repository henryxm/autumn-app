#import "AutumnOpsFusedDualFieldActionView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsFusedDualFieldActionView ()
@property (nonatomic, strong, readwrite) UITextField *primaryField;
@property (nonatomic, strong, readwrite) UITextField *secondaryField;
@property (nonatomic, strong, readwrite) UIButton *actionButton;
@end

@implementation AutumnOpsFusedDualFieldActionView

- (instancetype)initWithPrimaryHint:(NSString *)primaryHint
                      secondaryHint:(NSString *)secondaryHint
                        actionTitle:(NSString *)actionTitle
                             target:(id)target
                             action:(SEL)action {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.backgroundColor = AutumnOpsUITheme.surface;
    self.layer.cornerRadius = 12;
    self.clipsToBounds = YES;
    [AutumnOpsUITheme applyBorderToLayer:self.layer color:AutumnOpsUITheme.outlineVariant width:1];

    _primaryField = [UITextField new];
    _primaryField.borderStyle = UITextBorderStyleNone;
    _primaryField.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    _primaryField.textColor = AutumnOpsUITheme.onSurface;
    _primaryField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _primaryField.autocorrectionType = UITextAutocorrectionTypeNo;
    _primaryField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:primaryHint ?: @""
        attributes:@{NSForegroundColorAttributeName : [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.7]}];
    [_primaryField setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    _secondaryField = [UITextField new];
    _secondaryField.borderStyle = UITextBorderStyleNone;
    _secondaryField.font = [UIFont systemFontOfSize:15];
    _secondaryField.keyboardType = UIKeyboardTypeNumberPad;
    _secondaryField.textColor = AutumnOpsUITheme.onSurface;
    _secondaryField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:secondaryHint ?: @""
        attributes:@{NSForegroundColorAttributeName : [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.7]}];

    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_actionButton setTitle:actionTitle forState:UIControlStateNormal];
    _actionButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [_actionButton setTitleColor:AutumnOpsUITheme.primary forState:UIControlStateNormal];
    [_actionButton setTitleColor:[AutumnOpsUITheme.onSurface colorWithAlphaComponent:0.38] forState:UIControlStateDisabled];
    _actionButton.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
    [_actionButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    if (target && action) [_actionButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

    UIView *d1 = [UIView new];
    d1.backgroundColor = AutumnOpsUITheme.outlineVariant;
    UIView *d2 = [UIView new];
    d2.backgroundColor = AutumnOpsUITheme.outlineVariant;

    [self addSubview:_primaryField];
    [self addSubview:d1];
    [self addSubview:_secondaryField];
    [self addSubview:d2];
    [self addSubview:_actionButton];
    for (UIView *v in @[ _primaryField, d1, _secondaryField, d2, _actionButton ]) {
      v.translatesAutoresizingMaskIntoConstraints = NO;
    }
    [NSLayoutConstraint activateConstraints:@[
      [self.heightAnchor constraintEqualToConstant:48],
      [_primaryField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
      [_primaryField.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_primaryField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [_primaryField.trailingAnchor constraintEqualToAnchor:d1.leadingAnchor],
      [d1.widthAnchor constraintEqualToConstant:1],
      [d1.topAnchor constraintEqualToAnchor:self.topAnchor],
      [d1.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [_secondaryField.leadingAnchor constraintEqualToAnchor:d1.trailingAnchor constant:8],
      [_secondaryField.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_secondaryField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [_secondaryField.widthAnchor constraintEqualToConstant:88],
      [_secondaryField.trailingAnchor constraintEqualToAnchor:d2.leadingAnchor],
      [d2.widthAnchor constraintEqualToConstant:1],
      [d2.topAnchor constraintEqualToAnchor:self.topAnchor],
      [d2.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [d2.trailingAnchor constraintEqualToAnchor:_actionButton.leadingAnchor],
      [_actionButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [_actionButton.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_actionButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
  }
  return self;
}

- (void)setBarEnabled:(BOOL)enabled {
  self.primaryField.enabled = enabled;
  self.secondaryField.enabled = enabled;
  self.actionButton.enabled = enabled;
}

@end
