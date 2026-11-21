#import "AutumnOpsFusedActionBarView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsFusedActionBarView ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong, readwrite) UILabel *label;
@property (nonatomic, strong, readwrite) UIButton *actionButton;
@property (nonatomic, strong) UIView *divider;
@property (nonatomic) BOOL barEnabled;
@property (nonatomic) BOOL labelSelected;
@end

@implementation AutumnOpsFusedActionBarView

- (instancetype)initWithIconSystemName:(NSString *)systemName
                           actionTitle:(NSString *)actionTitle
                                target:(id)target
                                action:(SEL)action {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _barEnabled = YES;
    self.layer.cornerRadius = 12;
    self.clipsToBounds = YES;

    _iconView = [UIImageView new];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    if (systemName.length) {
      UIImageSymbolConfiguration *cfg =
          [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
      _iconView.image = [UIImage systemImageNamed:systemName withConfiguration:cfg];
    } else {
      _iconView.hidden = YES;
    }

    _label = [UILabel new];
    _label.font = [UIFont systemFontOfSize:14];
    _label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [_label setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                             forAxis:UILayoutConstraintAxisHorizontal];

    _divider = [UIView new];

    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_actionButton setTitle:actionTitle forState:UIControlStateNormal];
    _actionButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _actionButton.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
    [_actionButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_actionButton setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    if (target && action) {
      [_actionButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }

    [self addSubview:_iconView];
    [self addSubview:_label];
    [self addSubview:_divider];
    [self addSubview:_actionButton];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    _divider.translatesAutoresizingMaskIntoConstraints = NO;
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSLayoutConstraint *iconLead = [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12];
    NSLayoutConstraint *labelLead = systemName.length
        ? [_label.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:8]
        : [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14];

    [NSLayoutConstraint activateConstraints:@[
      [self.heightAnchor constraintEqualToConstant:52],
      iconLead,
      [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [_iconView.widthAnchor constraintEqualToConstant:systemName.length ? 20 : 0],
      [_iconView.heightAnchor constraintEqualToConstant:20],
      labelLead,
      [_label.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [_label.trailingAnchor constraintEqualToAnchor:_divider.leadingAnchor constant:-8],
      [_divider.widthAnchor constraintEqualToConstant:1],
      [_divider.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_divider.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [_divider.trailingAnchor constraintEqualToAnchor:_actionButton.leadingAnchor],
      [_actionButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [_actionButton.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_actionButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_barTapped)];
    [self addGestureRecognizer:tap];
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
  self.iconView.tintColor = AutumnOpsUITheme.onSurfaceVariant;
  self.divider.backgroundColor = AutumnOpsUITheme.outlineVariant;
  [self.actionButton setTitleColor:AutumnOpsUITheme.primary forState:UIControlStateNormal];
  [self.actionButton setTitleColor:[AutumnOpsUITheme.onSurface colorWithAlphaComponent:0.38] forState:UIControlStateDisabled];
  self.label.textColor = self.labelSelected
      ? AutumnOpsUITheme.onSurface
      : [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.85];
}

- (void)setLabelText:(NSString *)text selected:(BOOL)selected {
  self.label.text = text;
  self.labelSelected = selected;
  self.label.textColor = selected
      ? AutumnOpsUITheme.onSurface
      : [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.85];
}

- (void)setActionTitle:(NSString *)title {
  [self.actionButton setTitle:title forState:UIControlStateNormal];
  [self.actionButton invalidateIntrinsicContentSize];
}

- (void)setBarEnabled:(BOOL)enabled {
  _barEnabled = enabled;
  self.actionButton.enabled = enabled;
  self.alpha = enabled ? 1.0 : 0.6;
}

- (void)_barTapped {
  if (!self.barEnabled || !self.actionButton.enabled) return;
  [self.actionButton sendActionsForControlEvents:UIControlEventTouchUpInside];
}

@end
