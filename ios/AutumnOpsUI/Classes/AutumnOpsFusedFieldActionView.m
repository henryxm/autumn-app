#import "AutumnOpsFusedFieldActionView.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsFusedFieldActionView ()
@property (nonatomic, strong, readwrite) UITextField *textField;
@property (nonatomic, strong, readwrite) UIButton *actionButton;
@property (nonatomic, strong) UIView *divider;
@property (nonatomic, strong, nullable) UIView *trailingView;
@property (nonatomic, strong) NSLayoutConstraint *fieldTrailingToDivider;
@property (nonatomic, strong) NSLayoutConstraint *fieldTrailingToTrailing;
@end

@implementation AutumnOpsFusedFieldActionView

- (instancetype)initWithHint:(NSString *)hint
                 actionTitle:(NSString *)actionTitle
                      target:(id)target
                      action:(SEL)action {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.backgroundColor = AutumnOpsUITheme.surface;
    self.layer.cornerRadius = 12;
    self.clipsToBounds = YES;
    [AutumnOpsUITheme applyBorderToLayer:self.layer color:AutumnOpsUITheme.outlineVariant width:1];

    _textField = [UITextField new];
    _textField.borderStyle = UITextBorderStyleNone;
    _textField.font = [UIFont systemFontOfSize:15];
    _textField.textColor = AutumnOpsUITheme.onSurface;
    _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:hint ?: @""
        attributes:@{NSForegroundColorAttributeName : [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.7]}];
    // 对齐 Flutter Expanded：输入区吃满剩余宽度，勿被按钮挤扁
    [_textField setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_textField setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                 forAxis:UILayoutConstraintAxisHorizontal];

    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_actionButton setTitle:actionTitle forState:UIControlStateNormal];
    _actionButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [_actionButton setTitleColor:AutumnOpsUITheme.primary forState:UIControlStateNormal];
    [_actionButton setTitleColor:[AutumnOpsUITheme.onSurface colorWithAlphaComponent:0.38] forState:UIControlStateDisabled];
    // Flutter TextButton padding horizontal 16；固有宽度贴文案，禁止拉伸
    _actionButton.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
    [_actionButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_actionButton setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    if (target && action) {
      [_actionButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }

    _divider = [UIView new];
    _divider.backgroundColor = AutumnOpsUITheme.outlineVariant;
    [_divider setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_divider setContentCompressionResistancePriority:UILayoutPriorityRequired
                                               forAxis:UILayoutConstraintAxisHorizontal];

    [self addSubview:_textField];
    [self addSubview:_divider];
    [self addSubview:_actionButton];
    _textField.translatesAutoresizingMaskIntoConstraints = NO;
    _divider.translatesAutoresizingMaskIntoConstraints = NO;
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;

    _fieldTrailingToDivider = [_textField.trailingAnchor constraintEqualToAnchor:_divider.leadingAnchor constant:-4];
    _fieldTrailingToTrailing = nil;

    [NSLayoutConstraint activateConstraints:@[
      [self.heightAnchor constraintEqualToConstant:52],
      [_textField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
      [_textField.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_textField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      _fieldTrailingToDivider,
      [_divider.widthAnchor constraintEqualToConstant:1],
      [_divider.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_divider.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
      [_divider.trailingAnchor constraintEqualToAnchor:_actionButton.leadingAnchor],
      [_actionButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [_actionButton.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_actionButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
  }
  return self;
}

- (void)setActionTitle:(NSString *)title {
  [self.actionButton setTitle:title forState:UIControlStateNormal];
  [self.actionButton invalidateIntrinsicContentSize];
}

- (void)setActionEnabled:(BOOL)enabled {
  self.actionButton.enabled = enabled;
}

- (void)setFieldEnabled:(BOOL)enabled {
  self.textField.enabled = enabled;
}

- (void)setObscure:(BOOL)obscure {
  self.textField.secureTextEntry = obscure;
}

- (void)setTrailing:(UIView *)trailing {
  if (self.trailingView) {
    [self.trailingView removeFromSuperview];
    self.trailingView = nil;
  }
  self.fieldTrailingToDivider.active = NO;
  self.fieldTrailingToTrailing.active = NO;
  self.fieldTrailingToTrailing = nil;

  if (!trailing) {
    self.fieldTrailingToDivider = [self.textField.trailingAnchor constraintEqualToAnchor:self.divider.leadingAnchor
                                                                                constant:-4];
    self.fieldTrailingToDivider.active = YES;
    return;
  }

  self.trailingView = trailing;
  [self addSubview:trailing];
  trailing.translatesAutoresizingMaskIntoConstraints = NO;
  [trailing setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [trailing setContentCompressionResistancePriority:UILayoutPriorityRequired
                                             forAxis:UILayoutConstraintAxisHorizontal];

  self.fieldTrailingToTrailing = [self.textField.trailingAnchor constraintEqualToAnchor:trailing.leadingAnchor
                                                                               constant:-2];
  self.fieldTrailingToDivider = [trailing.trailingAnchor constraintEqualToAnchor:self.divider.leadingAnchor
                                                                       constant:-4];
  [NSLayoutConstraint activateConstraints:@[
    self.fieldTrailingToTrailing,
    [trailing.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
    [trailing.widthAnchor constraintEqualToConstant:36],
    [trailing.heightAnchor constraintEqualToConstant:36],
    self.fieldTrailingToDivider,
  ]];
}

@end
