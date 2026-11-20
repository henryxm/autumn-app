#import "AutumnOpsUIControls.h"
#import "AutumnOpsUITheme.h"

static const CGFloat kBtnMinH = 40.0;
static const CGFloat kBtnPadH = 24.0;
static const CGFloat kDisabledAlpha = 0.38;

@interface AutumnOpsChipView ()
@property (nonatomic, strong, readwrite) UILabel *label;
@property (nonatomic) BOOL compact;
@property (nonatomic) CGFloat padV;
@property (nonatomic) CGFloat padH;
@end

@implementation AutumnOpsChipView

- (instancetype)initWithCompact:(BOOL)compact {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _compact = compact;
    _padV = compact ? 2 : 4;
    _padH = 8;
    self.layer.cornerRadius = 8;
    self.clipsToBounds = YES;
    _label = [UILabel new];
    _label.textAlignment = NSTextAlignmentCenter;
    // Flutter：默认 Chip ≈ label 14 / 紧凑 Chip label 11 + padding zero + visualDensity.compact
    _label.font = compact
        ? [UIFont systemFontOfSize:11 weight:UIFontWeightMedium]
        : [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self addSubview:_label];
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_label.topAnchor constraintEqualToAnchor:self.topAnchor constant:_padV],
      [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-_padV],
      [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:_padH],
      [_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-_padH],
    ]];
    [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  }
  return self;
}

- (CGSize)intrinsicContentSize {
  CGSize s = [self.label sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
  if (s.width < 1 && self.label.text.length) {
    s = [self.label.text sizeWithAttributes:@{NSFontAttributeName : self.label.font ?: [UIFont systemFontOfSize:11]}];
  }
  return CGSizeMake(ceil(s.width) + self.padH * 2.0, ceil(s.height) + self.padV * 2.0);
}

- (void)invalidateChipSize {
  [self invalidateIntrinsicContentSize];
  [self setNeedsLayout];
}

@end

@implementation AutumnOpsUIControls

+ (UIButton *)buttonWithTitle:(NSString *)title
                        style:(AutumnOpsButtonStyle)style
                       target:(id)target
                       action:(SEL)action {
  UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
  [b setTitle:title forState:UIControlStateNormal];
  b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  b.titleLabel.numberOfLines = 1;
  b.contentEdgeInsets = UIEdgeInsetsMake(10, kBtnPadH, 10, kBtnPadH);
  [b.heightAnchor constraintGreaterThanOrEqualToConstant:kBtnMinH].active = YES;
  [self applyStyle:style toButton:b];
  if (target && action) {
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
  }
  return b;
}

+ (void)applyStyle:(AutumnOpsButtonStyle)style toButton:(UIButton *)button {
  button.clipsToBounds = YES;
  button.layer.cornerRadius = kBtnMinH / 2.0;
  switch (style) {
    case AutumnOpsButtonStyleFilled:
      button.backgroundColor = AutumnOpsUITheme.primary;
      [button setTitleColor:AutumnOpsUITheme.onPrimary forState:UIControlStateNormal];
      button.layer.borderWidth = 0;
      break;
    case AutumnOpsButtonStyleOutlined:
      button.backgroundColor = UIColor.clearColor;
      [button setTitleColor:AutumnOpsUITheme.primary forState:UIControlStateNormal];
      [AutumnOpsUITheme applyBorderToLayer:button.layer color:AutumnOpsUITheme.outline width:1];
      break;
    case AutumnOpsButtonStyleTonal:
      button.backgroundColor = AutumnOpsUITheme.secondaryContainer;
      [button setTitleColor:AutumnOpsUITheme.onSecondaryContainer forState:UIControlStateNormal];
      button.layer.borderWidth = 0;
      break;
  }
  [self setControl:button enabled:button.enabled];
}

+ (AutumnOpsChipView *)chipWithText:(NSString *)text kind:(AutumnOpsChipKind)kind {
  return [self chipWithText:text kind:kind compact:NO];
}

+ (AutumnOpsChipView *)chipWithText:(NSString *)text kind:(AutumnOpsChipKind)kind compact:(BOOL)compact {
  AutumnOpsChipView *chip = [[AutumnOpsChipView alloc] initWithCompact:compact];
  [self applyChipKind:kind toChip:chip text:text];
  return chip;
}

+ (void)applyChipKind:(AutumnOpsChipKind)kind toChip:(AutumnOpsChipView *)chip text:(NSString *)text {
  chip.label.text = text;
  [chip invalidateChipSize];
  // 与 Flutter Chip backgroundColor alpha 一致（非预烘焙叠色）
  switch (kind) {
    case AutumnOpsChipKindOn:
    case AutumnOpsChipKindReady:
      chip.backgroundColor = [AutumnOpsUITheme.secondaryContainer colorWithAlphaComponent:0.7];
      chip.label.textColor = AutumnOpsUITheme.onSecondaryContainer;
      break;
    case AutumnOpsChipKindSaved:
      chip.backgroundColor = [AutumnOpsUITheme.primaryContainer colorWithAlphaComponent:0.8];
      chip.label.textColor = AutumnOpsUITheme.onPrimaryContainer;
      break;
    case AutumnOpsChipKindOff:
      chip.backgroundColor = [AutumnOpsUITheme.errorContainer colorWithAlphaComponent:0.45];
      chip.label.textColor = AutumnOpsUITheme.onErrorContainer;
      break;
    case AutumnOpsChipKindError:
      chip.backgroundColor = [AutumnOpsUITheme.errorContainer colorWithAlphaComponent:0.75];
      chip.label.textColor = AutumnOpsUITheme.onErrorContainer;
      break;
    case AutumnOpsChipKindUnset:
      chip.backgroundColor = [AutumnOpsUITheme.errorContainer colorWithAlphaComponent:0.55];
      chip.label.textColor = AutumnOpsUITheme.onErrorContainer;
      break;
    case AutumnOpsChipKindEmpty:
      chip.backgroundColor = AutumnOpsUITheme.surfaceContainerHighest;
      chip.label.textColor = AutumnOpsUITheme.onSurfaceVariant;
      break;
    case AutumnOpsChipKindPending:
      chip.backgroundColor = [AutumnOpsUITheme.tertiaryContainer colorWithAlphaComponent:0.65];
      chip.label.textColor = AutumnOpsUITheme.onTertiaryContainer;
      break;
  }
}

+ (UIView *)tokenInputBarWithField:(UITextField **)outField
                       clearButton:(UIButton **)outClear
                      actionButton:(UIButton **)outAction
                            target:(id)target
                            action:(SEL)action {
  UIView *bar = [UIView new];
  bar.backgroundColor = AutumnOpsUITheme.surface;
  bar.layer.cornerRadius = 12;
  bar.clipsToBounds = YES;
  [AutumnOpsUITheme applyBorderToLayer:bar.layer color:AutumnOpsUITheme.outlineVariant width:1];

  UITextField *field = [UITextField new];
  field.secureTextEntry = YES;
  field.font = [UIFont systemFontOfSize:15];
  field.borderStyle = UITextBorderStyleNone;
  field.textColor = AutumnOpsUITheme.onSurface;
  field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"输入令牌后保存校验，或修改后保存"
                                                                attributes:@{NSForegroundColorAttributeName : [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.7]}];

  UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
  [clearBtn setImage:[UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:cfg] forState:UIControlStateNormal];
  clearBtn.tintColor = [AutumnOpsUITheme.onSurfaceVariant colorWithAlphaComponent:0.55];
  clearBtn.hidden = YES;

  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
  [btn setTitle:@"保存" forState:UIControlStateNormal];
  btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  [btn setTitleColor:AutumnOpsUITheme.primary forState:UIControlStateNormal];
  [btn setTitleColor:[AutumnOpsUITheme.onSurface colorWithAlphaComponent:0.38] forState:UIControlStateDisabled];
  btn.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);
  if (target && action) {
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
  }

  UIView *divider = [UIView new];
  divider.backgroundColor = AutumnOpsUITheme.outlineVariant;

  [bar addSubview:field];
  [bar addSubview:clearBtn];
  [bar addSubview:divider];
  [bar addSubview:btn];
  field.translatesAutoresizingMaskIntoConstraints = NO;
  clearBtn.translatesAutoresizingMaskIntoConstraints = NO;
  divider.translatesAutoresizingMaskIntoConstraints = NO;
  btn.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [bar.heightAnchor constraintEqualToConstant:52],
    [field.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:14],
    [field.topAnchor constraintEqualToAnchor:bar.topAnchor],
    [field.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
    [field.trailingAnchor constraintEqualToAnchor:clearBtn.leadingAnchor constant:-4],
    [clearBtn.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
    [clearBtn.widthAnchor constraintEqualToConstant:28],
    [clearBtn.heightAnchor constraintEqualToConstant:28],
    [clearBtn.trailingAnchor constraintEqualToAnchor:divider.leadingAnchor constant:-4],
    [divider.widthAnchor constraintEqualToConstant:1],
    [divider.topAnchor constraintEqualToAnchor:bar.topAnchor],
    [divider.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
    [divider.trailingAnchor constraintEqualToAnchor:btn.leadingAnchor],
    [btn.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
    [btn.topAnchor constraintEqualToAnchor:bar.topAnchor],
    [btn.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
    [btn.widthAnchor constraintGreaterThanOrEqualToConstant:64],
  ]];

  if (outField) *outField = field;
  if (outClear) *outClear = clearBtn;
  if (outAction) *outAction = btn;
  return bar;
}

+ (void)setControl:(UIView *)view enabled:(BOOL)enabled {
  if ([view isKindOfClass:[UIControl class]]) {
    ((UIControl *)view).enabled = enabled;
  }
  view.alpha = enabled ? 1.0 : kDisabledAlpha;
  view.userInteractionEnabled = enabled;
}

@end
