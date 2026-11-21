#import "AutumnOpsSiteListCell.h"
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

    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];

    _renameBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_renameBtn setImage:[UIImage systemImageNamed:@"pencil" withConfiguration:cfg] forState:UIControlStateNormal];
    _renameBtn.tintColor = AutumnOpsUITheme.onSurfaceVariant;
    _renameBtn.accessibilityLabel = @"修改名称";
    [_renameBtn addTarget:self action:@selector(_renameTapped) forControlEvents:UIControlEventTouchUpInside];

    _deleteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_deleteBtn setImage:[UIImage systemImageNamed:@"trash" withConfiguration:cfg] forState:UIControlStateNormal];
    _deleteBtn.tintColor = AutumnOpsUITheme.onSurfaceVariant;
    _deleteBtn.accessibilityLabel = @"从本机移除";
    [_deleteBtn addTarget:self action:@selector(_deleteTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *textCol = [[UIStackView alloc] initWithArrangedSubviews:@[ _titleLabel, _subtitleLabel ]];
    textCol.axis = UILayoutConstraintAxisVertical;
    textCol.spacing = 4;
    textCol.alignment = UIStackViewAlignmentFill;
    [_titleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_subtitleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ textCol, _renameBtn, _deleteBtn ]];
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
    [_renameBtn mas_makeConstraints:^(MASConstraintMaker *make) {
      make.width.height.mas_equalTo(40);
    }];
    [_deleteBtn mas_makeConstraints:^(MASConstraintMaker *make) {
      make.width.height.mas_equalTo(40);
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
