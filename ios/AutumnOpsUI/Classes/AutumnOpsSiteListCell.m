#import "AutumnOpsSiteListCell.h"
#import "AutumnOpsRuleRowChromeView.h"
#import "AutumnOpsUITheme.h"
#import <AutumnOpsCore/AutumnOpsCore.h>
#import <Masonry/Masonry.h>

@interface AutumnOpsSiteListCell ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *renameBtn;
@property (nonatomic, strong) UIButton *deleteBtn;
@end

@implementation AutumnOpsSiteListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _card = [UIView new];
    _card.backgroundColor = [AutumnOpsUITheme.surfaceContainerHighest colorWithAlphaComponent:0.5];
    _card.layer.cornerRadius = 14;
    _card.clipsToBounds = YES;
    [self.contentView addSubview:_card];

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _titleLabel.textColor = AutumnOpsUITheme.onSurface;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    _subtitleLabel = [UILabel new];
    _subtitleLabel.font = [UIFont systemFontOfSize:13];
    _subtitleLabel.textColor = AutumnOpsUITheme.onSurfaceVariant;
    _subtitleLabel.numberOfLines = 0;

    // 与 Flutter OpsRuleRowChrome / IP 行动作钮：槽 32、图标 20 scaleSmall、onSurfaceVariant
    UIColor *actionColor = AutumnOpsUITheme.onSurfaceVariant;
    _renameBtn = [AutumnOpsRuleRowChromeView iconActionSystemName:@"pencil"
                                                            color:actionColor
                                                           target:self
                                                           action:@selector(_renameTapped)
                                              accessibilityLabel:@"修改名称"];
    _deleteBtn = [AutumnOpsRuleRowChromeView iconActionSystemName:@"trash"
                                                            color:actionColor
                                                           target:self
                                                           action:@selector(_deleteTapped)
                                              accessibilityLabel:@"从本机移除"];

    UIStackView *textCol = [[UIStackView alloc] initWithArrangedSubviews:@[ _titleLabel, _subtitleLabel ]];
    textCol.axis = UILayoutConstraintAxisVertical;
    textCol.spacing = 4;
    textCol.alignment = UIStackViewAlignmentFill;
    [_titleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_subtitleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    // 修改在上、删除在下，右对齐
    UIStackView *actionsCol = [[UIStackView alloc] initWithArrangedSubviews:@[ _renameBtn, _deleteBtn ]];
    actionsCol.axis = UILayoutConstraintAxisVertical;
    actionsCol.alignment = UIStackViewAlignmentTrailing;
    actionsCol.spacing = 0;
    [actionsCol setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [actionsCol setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ textCol, actionsCol ]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 4;
    [_card addSubview:row];

    [_card mas_makeConstraints:^(MASConstraintMaker *make) {
      make.top.equalTo(self.contentView);
      make.left.right.equalTo(self.contentView).inset(12);
      make.bottom.equalTo(self.contentView).offset(-10);
    }];
    [row mas_makeConstraints:^(MASConstraintMaker *make) {
      make.edges.equalTo(self.card).insets(UIEdgeInsetsMake(12, 16, 12, 8));
    }];
  }
  return self;
}

- (void)configureWithSite:(AutumnOpsSiteEntry *)site {
  NSString *title = site.title.length ? site.title : (site.baseUrl ?: @"");
  self.titleLabel.text = title;
  NSMutableString *sub = [NSMutableString stringWithFormat:@"%@\n%@", site.baseUrl ?: @"", site.enrolled ? @"本机已入驻" : @"本机未入驻"];
  if (site.serverFingerprint.length) {
    [sub appendFormat:@" · 指纹 %@", site.serverFingerprint];
  }
  NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
  ps.lineHeightMultiple = 1.35;
  self.subtitleLabel.attributedText = [[NSAttributedString alloc] initWithString:sub
      attributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:13],
        NSForegroundColorAttributeName : AutumnOpsUITheme.onSurfaceVariant,
        NSParagraphStyleAttributeName : ps,
      }];
}

- (void)_renameTapped {
  if (self.onRename) self.onRename();
}

- (void)_deleteTapped {
  if (self.onDelete) self.onDelete();
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
  [super setHighlighted:highlighted animated:animated];
  self.card.alpha = highlighted ? 0.85 : 1.0;
}

@end
