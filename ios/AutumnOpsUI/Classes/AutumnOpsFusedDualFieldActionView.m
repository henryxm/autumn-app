#import "AutumnOpsFusedDualFieldActionView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsFusedDualFieldActionView ()
@property (nonatomic, strong, readwrite) UITextField *primaryField;
@property (nonatomic, strong, readwrite) UITextField *secondaryField;
@property (nonatomic, strong, readwrite) UIButton *actionButton;
@property (nonatomic, strong) UIView *divider1;
@property (nonatomic, strong) UIView *divider2;
@property (nonatomic, copy) NSString *primaryHintText;
@property (nonatomic, copy) NSString *secondaryHintText;
@end

@implementation AutumnOpsFusedDualFieldActionView

- (instancetype)initWithPrimaryHint:(NSString *)primaryHint
                      secondaryHint:(NSString *)secondaryHint
                        actionTitle:(NSString *)actionTitle
                             target:(id)target
                             action:(SEL)action {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _primaryHintText = [primaryHint copy] ?: @"";
    _secondaryHintText = [secondaryHint copy] ?: @"";
    self.layer.cornerRadius = 12;
    self.clipsToBounds = YES;

    _primaryField = [UITextField new];
    _primaryField.borderStyle = UITextBorderStyleNone;
    _primaryField.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    _primaryField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _primaryField.autocorrectionType = UITextAutocorrectionTypeNo;
    [_primaryField setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    _secondaryField = [UITextField new];
    _secondaryField.borderStyle = UITextBorderStyleNone;
    _secondaryField.font = [UIFont systemFontOfSize:15];
    _secondaryField.keyboardType = UIKeyboardTypeNumberPad;

    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_actionButton setTitle:actionTitle forState:UIControlStateNormal];
    _actionButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _actionButton.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
    [_actionButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    if (target && action) [_actionButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

    _divider1 = [UIView new];
    _divider2 = [UIView new];

    [self addSubview:_primaryField];
    [self addSubview:_divider1];
    [self addSubview:_secondaryField];
    [self addSubview:_divider2];
    [self addSubview:_actionButton];
    for (UIView *v in @[ _primaryField, _divider1, _secondaryField, _divider2, _actionButton ]) {
      v.translatesAutoresizingMaskIntoConstraints = NO;
    }
    [NSLayoutConstraint activateConstraints:@[
      [self.heightAnchor constraintEqualToConstant:48],
      [_primaryField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
      [_primaryField.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_primaryField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [_primaryField.trailingAnchor constraintEqualToAnchor:_divider1.leadingAnchor],
      [_divider1.widthAnchor constraintEqualToConstant:1],
      [_divider1.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_divider1.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [_secondaryField.leadingAnchor constraintEqualToAnchor:_divider1.trailingAnchor constant:8],
      [_secondaryField.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_secondaryField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [_secondaryField.widthAnchor constraintEqualToConstant:88],
      [_secondaryField.trailingAnchor constraintEqualToAnchor:_divider2.leadingAnchor],
      [_divider2.widthAnchor constraintEqualToConstant:1],
      [_divider2.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_divider2.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [_divider2.trailingAnchor constraintEqualToAnchor:_actionButton.leadingAnchor],
      [_actionButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [_actionButton.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_actionButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
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
  self.backgroundColor = AutumnOpsUITheme.surface;
  [AutumnOpsUITheme applyBorderToLayer:self.layer color:AutumnOpsUITheme.outlineVariant width:1];
  self.primaryField.textColor = AutumnOpsUITheme.onSurface;
  self.primaryField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.primaryHintText
      attributes:@{NSForegroundColorAttributeName : [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.7]}];
  self.secondaryField.textColor = AutumnOpsUITheme.onSurface;
  self.secondaryField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.secondaryHintText
      attributes:@{NSForegroundColorAttributeName : [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.7]}];
  [self.actionButton setTitleColor:AutumnOpsUITheme.primary forState:UIControlStateNormal];
  [self.actionButton setTitleColor:[AutumnOpsUITheme.onSurface colorWithAlphaComponent:0.38] forState:UIControlStateDisabled];
  self.divider1.backgroundColor = AutumnOpsUITheme.outlineVariant;
  self.divider2.backgroundColor = AutumnOpsUITheme.outlineVariant;
}

- (void)setBarEnabled:(BOOL)enabled {
  self.primaryField.enabled = enabled;
  self.secondaryField.enabled = enabled;
  self.actionButton.enabled = enabled;
}

@end
