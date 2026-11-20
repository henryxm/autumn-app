#import "AutumnOpsRuleRowChromeView.h"
#import "AutumnOpsStatusPillView.h"
#import "AutumnOpsUITheme.h"

/// 与 Flutter `OpsRuleRowChrome.actionSlotWidth` / `actionIconSize` 锁死。
static const CGFloat kAutumnOpsActionSlot = 32;
static const CGFloat kAutumnOpsActionIcon = 20;

@interface AutumnOpsRuleRowChromeView ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *accent;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) AutumnOpsStatusPillView *pill;
@property (nonatomic, strong) UIStackView *statusCluster; // 本机 → 胶囊 → 启停
@property (nonatomic, strong) UIStackView *metaStack;
@property (nonatomic, strong) UIStackView *actionsRow;
@property (nonatomic, strong) UIStackView *bodyCol;
@property (nonatomic, strong) UIStackView *lowerCol;
@property (nonatomic, strong) UIView *titleRow;
@property (nonatomic, strong) UIView *lowerRow;
@property (nonatomic, strong, nullable) UIView *primaryActionHost;
@property (nonatomic, strong, nullable) UIView *trailingHost;
@property (nonatomic, strong, nullable) NSLayoutConstraint *lowerColToRowTrailing;
@property (nonatomic, strong, nullable) NSLayoutConstraint *lowerColToTrailingHost;
@property (nonatomic) BOOL highlightedBorder;
@property (nonatomic) BOOL hasSplitBody;
@end

@implementation AutumnOpsRuleRowChromeView

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                       active:(BOOL)active
                  statusLabel:(NSString *)statusLabel
               titleMonospace:(BOOL)titleMonospace {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;

    _card = [UIView new];
    _card.backgroundColor = AutumnOpsUITheme.surface;
    _card.layer.cornerRadius = 12;
    _card.clipsToBounds = YES;
    [self addSubview:_card];
    _card.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_card.topAnchor constraintEqualToAnchor:self.topAnchor],
      [_card.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [_card.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [_card.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],
    ]];
    [self setHighlightedBorder:NO];

    _accent = [UIView new];
    _accent.backgroundColor = active ? AutumnOpsUITheme.tertiary : AutumnOpsUITheme.outlineVariant;

    _titleLabel = [UILabel new];
    _titleLabel.numberOfLines = 0;
    _titleLabel.lineBreakMode = NSLineBreakByCharWrapping;
    UIFont *titleFont = titleMonospace
        ? [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightSemibold]
        : [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    NSMutableParagraphStyle *titlePS = [NSMutableParagraphStyle new];
    titlePS.lineHeightMultiple = 1.25;
    _titleLabel.attributedText = [[NSAttributedString alloc] initWithString:title ?: @""
                                                                attributes:@{
                                                                  NSFontAttributeName : titleFont,
                                                                  NSForegroundColorAttributeName : AutumnOpsUITheme.onSurface,
                                                                  NSParagraphStyleAttributeName : titlePS,
                                                                }];

    _metaStack = [UIStackView new];
    _metaStack.axis = UILayoutConstraintAxisHorizontal;
    _metaStack.spacing = 6;
    _metaStack.alignment = UIStackViewAlignmentCenter;
    _metaStack.hidden = YES;

    _pill = [[AutumnOpsStatusPillView alloc] initWithLabel:statusLabel active:active];

    _primaryActionHost = [UIView new];
    _primaryActionHost.hidden = YES;
    [_primaryActionHost.widthAnchor constraintEqualToConstant:kAutumnOpsActionSlot].active = YES;
    [_primaryActionHost.heightAnchor constraintEqualToConstant:kAutumnOpsActionSlot].active = YES;

    // 本机 → 胶囊 → 启停：整组 hugging，贴 titleRow 右侧
    _statusCluster = [[UIStackView alloc] initWithArrangedSubviews:@[ _metaStack, _pill, _primaryActionHost ]];
    _statusCluster.axis = UILayoutConstraintAxisHorizontal;
    _statusCluster.spacing = 6;
    _statusCluster.alignment = UIStackViewAlignmentCenter;

    // IP 与 statusCluster（本机/胶囊/启停）同一行垂直居中；行高取两者较大值
    _titleRow = [UIView new];
    [_titleRow addSubview:_titleLabel];
    [_titleRow addSubview:_statusCluster];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusCluster.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_titleLabel.leadingAnchor constraintEqualToAnchor:_titleRow.leadingAnchor],
      [_titleLabel.centerYAnchor constraintEqualToAnchor:_titleRow.centerYAnchor],
      [_titleLabel.topAnchor constraintGreaterThanOrEqualToAnchor:_titleRow.topAnchor],
      [_titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_titleRow.bottomAnchor],
      [_statusCluster.leadingAnchor constraintGreaterThanOrEqualToAnchor:_titleLabel.trailingAnchor constant:8],
      [_statusCluster.trailingAnchor constraintEqualToAnchor:_titleRow.trailingAnchor],
      [_statusCluster.centerYAnchor constraintEqualToAnchor:_titleRow.centerYAnchor],
      [_statusCluster.topAnchor constraintEqualToAnchor:_titleRow.topAnchor],
      [_statusCluster.bottomAnchor constraintEqualToAnchor:_titleRow.bottomAnchor],
    ]];
    [_titleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_statusCluster setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_statusCluster setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    [_statusCluster setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

    _detailLabel = [UILabel new];
    _detailLabel.numberOfLines = 0;
    _detailLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _detailLabel.hidden = YES;

    _dateLabel = [UILabel new];
    _dateLabel.numberOfLines = 1;
    _dateLabel.hidden = YES;

    _subtitleLabel = [UILabel new];
    _subtitleLabel.numberOfLines = 0;
    _subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self _applyBodyLabel:_subtitleLabel text:subtitle];
    _subtitleLabel.hidden = subtitle.length == 0;

    _actionsRow = [UIStackView new];
    _actionsRow.axis = UILayoutConstraintAxisHorizontal;
    _actionsRow.spacing = 4;
    _actionsRow.alignment = UIStackViewAlignmentCenter;
    _actionsRow.hidden = YES;

    _lowerCol = [[UIStackView alloc] initWithArrangedSubviews:@[ _detailLabel, _dateLabel, _subtitleLabel, _actionsRow ]];
    _lowerCol.axis = UILayoutConstraintAxisVertical;
    _lowerCol.spacing = 4;
    _lowerCol.alignment = UIStackViewAlignmentFill;

    _trailingHost = [UIView new];
    _trailingHost.hidden = YES;
    [_trailingHost.widthAnchor constraintEqualToConstant:kAutumnOpsActionSlot].active = YES;

    // 说明/日期 | 删除（与启停同宽槽、右缘对齐）
    _lowerRow = [UIView new];
    [_lowerRow addSubview:_lowerCol];
    [_lowerRow addSubview:_trailingHost];
    _lowerCol.translatesAutoresizingMaskIntoConstraints = NO;
    _trailingHost.translatesAutoresizingMaskIntoConstraints = NO;
    _lowerColToRowTrailing = [_lowerCol.trailingAnchor constraintEqualToAnchor:_lowerRow.trailingAnchor];
    _lowerColToTrailingHost = [_lowerCol.trailingAnchor constraintEqualToAnchor:_trailingHost.leadingAnchor];
    _lowerColToTrailingHost.active = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_lowerCol.leadingAnchor constraintEqualToAnchor:_lowerRow.leadingAnchor],
      [_lowerCol.topAnchor constraintEqualToAnchor:_lowerRow.topAnchor],
      [_lowerCol.bottomAnchor constraintEqualToAnchor:_lowerRow.bottomAnchor],
      _lowerColToRowTrailing,
      [_trailingHost.trailingAnchor constraintEqualToAnchor:_lowerRow.trailingAnchor],
      [_trailingHost.bottomAnchor constraintEqualToAnchor:_lowerRow.bottomAnchor],
      [_trailingHost.topAnchor constraintGreaterThanOrEqualToAnchor:_lowerRow.topAnchor],
    ]];

    _bodyCol = [[UIStackView alloc] initWithArrangedSubviews:@[ _titleRow, _lowerRow ]];
    _bodyCol.axis = UILayoutConstraintAxisVertical;
    _bodyCol.spacing = 6;
    _bodyCol.alignment = UIStackViewAlignmentFill;

    [_card addSubview:_accent];
    [_card addSubview:_bodyCol];
    _accent.translatesAutoresizingMaskIntoConstraints = NO;
    _bodyCol.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_accent.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
      [_accent.topAnchor constraintEqualToAnchor:_card.topAnchor],
      [_accent.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor],
      [_accent.widthAnchor constraintEqualToConstant:4],
      [_bodyCol.leadingAnchor constraintEqualToAnchor:_accent.trailingAnchor constant:12],
      [_bodyCol.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-8],
      [_bodyCol.topAnchor constraintEqualToAnchor:_card.topAnchor constant:10],
      [_bodyCol.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-8],
    ]];
    [self _refreshLowerVisibility];
  }
  return self;
}

- (void)_applyBodyLabel:(UILabel *)label text:(NSString *)text {
  if (text.length == 0) {
    label.attributedText = nil;
    label.text = nil;
    return;
  }
  NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
  ps.lineHeightMultiple = 1.35;
  ps.lineBreakMode = NSLineBreakByWordWrapping;
  label.attributedText = [[NSAttributedString alloc] initWithString:text
                                                         attributes:@{
                                                           NSFontAttributeName : [UIFont systemFontOfSize:13],
                                                           NSForegroundColorAttributeName : AutumnOpsUITheme.onSurfaceVariant,
                                                           NSParagraphStyleAttributeName : ps,
                                                         }];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat rowW = CGRectGetWidth(self.titleRow.bounds);
  if (rowW > 1) {
    CGFloat clusterW = CGRectGetWidth(self.statusCluster.bounds);
    self.titleLabel.preferredMaxLayoutWidth = MAX(40, rowW - clusterW - 8);
  }
  CGFloat lowerW = CGRectGetWidth(self.lowerCol.bounds);
  if (lowerW > 1) {
    self.detailLabel.preferredMaxLayoutWidth = lowerW;
    self.dateLabel.preferredMaxLayoutWidth = lowerW;
    self.subtitleLabel.preferredMaxLayoutWidth = lowerW;
  }
}

- (void)_refreshLowerVisibility {
  if (self.hasSplitBody) self.subtitleLabel.hidden = YES;
  BOOL hasBody = !self.detailLabel.hidden || !self.dateLabel.hidden || !self.subtitleLabel.hidden ||
      !self.actionsRow.hidden;
  BOOL showTrailing = !self.trailingHost.hidden;
  self.lowerRow.hidden = !(hasBody || showTrailing);
  self.lowerColToRowTrailing.active = !showTrailing;
  self.lowerColToTrailingHost.active = showTrailing;
}

- (void)_syncPrimaryInCluster {
  // Stack 对 hidden arrangedSubview 仍占位时，用 hidden + 不参与：iOS 9+ stack 尊重 hidden
  self.primaryActionHost.hidden = (self.primaryActionHost.subviews.count == 0);
}

- (void)setHighlightedBorder:(BOOL)highlighted {
  _highlightedBorder = highlighted;
  UIColor *c = highlighted
      ? [AutumnOpsUITheme.primary colorWithAlphaComponent:0.45]
      : [AutumnOpsUITheme.outlineVariant colorWithAlphaComponent:0.8];
  [AutumnOpsUITheme applyBorderToLayer:self.card.layer color:c width:1];
}

- (void)setDetail:(NSString *)detail dateLine:(NSString *)dateLine {
  BOOL hasDetail = detail.length > 0;
  BOOL hasDate = dateLine.length > 0;
  self.hasSplitBody = hasDetail || hasDate;
  [self _applyBodyLabel:self.detailLabel text:hasDetail ? detail : nil];
  self.detailLabel.hidden = !hasDetail;
  [self _applyBodyLabel:self.dateLabel text:hasDate ? dateLine : nil];
  self.dateLabel.hidden = !hasDate;
  [self _refreshLowerVisibility];
  [self setNeedsLayout];
}

- (void)setMetaViews:(NSArray<UIView *> *)views {
  for (UIView *v in [self.metaStack.arrangedSubviews copy]) {
    [self.metaStack removeArrangedSubview:v];
    [v removeFromSuperview];
  }
  for (UIView *v in views ?: @[]) [self.metaStack addArrangedSubview:v];
  self.metaStack.hidden = views.count == 0;
  [self setNeedsLayout];
}

- (void)_pinChild:(UIView *)child inHost:(UIView *)host {
  for (UIView *v in [host.subviews copy]) [v removeFromSuperview];
  if (!child) return;
  [host addSubview:child];
  child.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [child.centerXAnchor constraintEqualToAnchor:host.centerXAnchor],
    [child.centerYAnchor constraintEqualToAnchor:host.centerYAnchor],
    [child.widthAnchor constraintLessThanOrEqualToAnchor:host.widthAnchor],
    [child.heightAnchor constraintLessThanOrEqualToAnchor:host.heightAnchor],
  ]];
}

- (void)setPrimaryActionView:(UIView *)view {
  [self _pinChild:view inHost:self.primaryActionHost];
  [self _syncPrimaryInCluster];
  [self setNeedsLayout];
}

- (void)setTrailingActionView:(UIView *)view {
  [self _pinChild:view inHost:self.trailingHost];
  self.trailingHost.hidden = (view == nil);
  // 无删除时仍保持 trailing 槽隐藏，lower 文案拉满
  if (view != nil) {
    [self.trailingHost.heightAnchor constraintGreaterThanOrEqualToConstant:kAutumnOpsActionSlot].active = YES;
  }
  [self _refreshLowerVisibility];
  [self setNeedsLayout];
}

- (void)setActionViews:(NSArray<UIView *> *)actions {
  for (UIView *v in [self.actionsRow.arrangedSubviews copy]) {
    [self.actionsRow removeArrangedSubview:v];
    [v removeFromSuperview];
  }
  for (UIView *a in actions) [self.actionsRow addArrangedSubview:a];
  self.actionsRow.hidden = actions.count == 0;
  [self _refreshLowerVisibility];
}

+ (UIButton *)textAction:(NSString *)title target:(id)target action:(SEL)action {
  UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
  [b setTitle:title forState:UIControlStateNormal];
  b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
  [b setTitleColor:AutumnOpsUITheme.primary forState:UIControlStateNormal];
  b.contentEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 8);
  if (target && action) [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
  return b;
}

+ (UIButton *)destructiveTextAction:(NSString *)title target:(id)target action:(SEL)action {
  UIButton *b = [self textAction:title target:target action:action];
  [b setTitleColor:AutumnOpsUITheme.error forState:UIControlStateNormal];
  return b;
}

+ (UIButton *)iconActionSystemName:(NSString *)systemName
                             color:(UIColor *)color
                            target:(id)target
                            action:(SEL)action
               accessibilityLabel:(NSString *)accessibilityLabel {
  UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
  // SF Symbol 同 pt 比 Material 显得更大：scaleSmall 与 Flutter actionIconSize=20 目视对齐
  UIImageSymbolConfiguration *cfg =
      [UIImageSymbolConfiguration configurationWithPointSize:kAutumnOpsActionIcon
                                                      weight:UIImageSymbolWeightRegular
                                                       scale:UIImageSymbolScaleSmall];
  UIImage *img = [[UIImage systemImageNamed:systemName withConfiguration:cfg]
      imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  [b setImage:img forState:UIControlStateNormal];
  b.tintColor = color;
  b.contentEdgeInsets = UIEdgeInsetsZero;
  b.imageView.contentMode = UIViewContentModeScaleAspectFit;
  [b.widthAnchor constraintEqualToConstant:kAutumnOpsActionSlot].active = YES;
  [b.heightAnchor constraintEqualToConstant:kAutumnOpsActionSlot].active = YES;
  b.accessibilityLabel = accessibilityLabel;
  if (target && action) [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
  return b;
}

@end
