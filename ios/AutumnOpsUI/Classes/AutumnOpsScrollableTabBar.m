#import "AutumnOpsScrollableTabBar.h"
#import "AutumnOpsUITheme.h"

static const CGFloat kLabelPadH = 14.0;
static const CGFloat kIndicatorH = 2.0;
static const CGFloat kFontSize = 13.0;

static inline UIColor *AutumnOpsTabAccent(void) {
  return AutumnOpsUITheme.tabAccent;
}

@interface AutumnOpsScrollableTabBar ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) NSMutableArray<UIButton *> *buttons;
@property (nonatomic, strong) UIView *bottomHairline;
@end

@implementation AutumnOpsScrollableTabBar

- (instancetype)initWithItems:(NSArray<NSString *> *)items {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _items = [items copy] ?: @[];
    _selectedIndex = 0;
    _buttons = [NSMutableArray array];
    [self _build];
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
  return [self initWithItems:@[]];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  return [self initWithItems:@[]];
}

- (void)_build {
  self.backgroundColor = UIColor.systemBackgroundColor;

  _scroll = [UIScrollView new];
  _scroll.showsHorizontalScrollIndicator = NO;
  _scroll.showsVerticalScrollIndicator = NO;
  _scroll.alwaysBounceHorizontal = YES;
  _scroll.clipsToBounds = YES;
  [self addSubview:_scroll];

  _content = [UIView new];
  [_scroll addSubview:_content];

  _indicator = [UIView new];
  _indicator.backgroundColor = AutumnOpsTabAccent();
  [_content addSubview:_indicator];

  _bottomHairline = [UIView new];
  _bottomHairline.backgroundColor = [UIColor separatorColor];
  [self addSubview:_bottomHairline];

  [self _rebuildButtons];
}

- (void)tintColorDidChange {
  [super tintColorDidChange];
  self.indicator.backgroundColor = AutumnOpsTabAccent();
  [self _applySelectionStyle];
}

- (void)setItems:(NSArray<NSString *> *)items {
  _items = [items copy] ?: @[];
  if (_selectedIndex >= (NSInteger)_items.count) {
    _selectedIndex = MAX(0, (NSInteger)_items.count - 1);
  }
  [self _rebuildButtons];
  [self setNeedsLayout];
}

- (void)setSelectedIndex:(NSInteger)selectedIndex {
  if (selectedIndex < 0 || selectedIndex >= (NSInteger)self.buttons.count) return;
  if (_selectedIndex == selectedIndex) {
    [self _scrollSelectedVisibleAnimated:YES];
    return;
  }
  _selectedIndex = selectedIndex;
  [self _applySelectionStyle];
  [self setNeedsLayout];
  [self layoutIfNeeded];
  [self _scrollSelectedVisibleAnimated:YES];
}

- (void)_rebuildButtons {
  for (UIButton *b in self.buttons) [b removeFromSuperview];
  [self.buttons removeAllObjects];
  for (NSInteger i = 0; i < (NSInteger)self.items.count; i++) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.tag = i;
    [b setTitle:self.items[i] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:kFontSize];
    [b addTarget:self action:@selector(_tap:) forControlEvents:UIControlEventTouchUpInside];
    [self.content addSubview:b];
    [self.buttons addObject:b];
  }
  [self.content bringSubviewToFront:self.indicator];
  [self _applySelectionStyle];
}

- (void)_applySelectionStyle {
  UIColor *selected = AutumnOpsTabAccent();
  UIColor *unselected = UIColor.secondaryLabelColor;
  for (UIButton *b in self.buttons) {
    BOOL on = b.tag == self.selectedIndex;
    b.titleLabel.font = on
        ? [UIFont systemFontOfSize:kFontSize weight:UIFontWeightSemibold]
        : [UIFont systemFontOfSize:kFontSize weight:UIFontWeightRegular];
    [b setTitleColor:on ? selected : unselected forState:UIControlStateNormal];
  }
  self.indicator.backgroundColor = selected;
}

- (void)_tap:(UIButton *)sender {
  NSInteger idx = sender.tag;
  if (idx == self.selectedIndex) return;
  self.selectedIndex = idx;
  [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)_scrollSelectedVisibleAnimated:(BOOL)animated {
  if (self.selectedIndex < 0 || self.selectedIndex >= (NSInteger)self.buttons.count) return;
  UIButton *b = self.buttons[self.selectedIndex];
  CGRect target = [self.content convertRect:b.frame toView:self.scroll];
  CGFloat pad = 24;
  target = CGRectInset(target, -pad, 0);
  [self.scroll scrollRectToVisible:target animated:animated];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat w = CGRectGetWidth(self.bounds);
  CGFloat h = CGRectGetHeight(self.bounds);
  self.scroll.frame = CGRectMake(0, 0, w, h);
  self.bottomHairline.frame = CGRectMake(0, h - 1.0 / UIScreen.mainScreen.scale, w, 1.0 / UIScreen.mainScreen.scale);

  CGFloat x = 0;
  CGFloat btnH = h - kIndicatorH;
  for (UIButton *b in self.buttons) {
    [b.titleLabel sizeToFit];
    CGFloat tw = ceil(b.titleLabel.bounds.size.width) + kLabelPadH * 2;
    b.frame = CGRectMake(x, 0, tw, btnH);
    x += tw;
  }
  CGFloat contentW = MAX(x, w);
  self.content.frame = CGRectMake(0, 0, contentW, h);
  self.scroll.contentSize = CGSizeMake(contentW, h);

  if (self.selectedIndex >= 0 && self.selectedIndex < (NSInteger)self.buttons.count) {
    UIButton *b = self.buttons[self.selectedIndex];
    self.indicator.frame = CGRectMake(CGRectGetMinX(b.frame), h - kIndicatorH, CGRectGetWidth(b.frame), kIndicatorH);
  } else {
    self.indicator.frame = CGRectZero;
  }
}

- (CGSize)intrinsicContentSize {
  return CGSizeMake(UIViewNoIntrinsicMetric, 46);
}

@end
