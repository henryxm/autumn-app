#import "AutumnOpsJumpEditorController.h"
#import "AutumnOpsSwitchRowView.h"
#import "AutumnOpsUIControls.h"
#import "AutumnOpsUITheme.h"

@implementation AutumnOpsJumpEditorResult
@end

@interface AutumnOpsJumpEditorController ()
@property (nonatomic, copy, nullable) NSString *initialHost;
@property (nonatomic, copy, nullable) NSString *initialUri;
@property (nonatomic, copy, nullable) NSString *initialUrl;
@property (nonatomic) BOOL initialEnable;
@property (nonatomic) BOOL isEdit;
@property (nonatomic, strong) UITextField *hostField;
@property (nonatomic, strong) UITextField *uriField;
@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, strong) AutumnOpsSwitchRowView *enableRow;
@end

@implementation AutumnOpsJumpEditorController

- (instancetype)initWithExistingHost:(NSString *)host
                                 uri:(NSString *)uri
                                 url:(NSString *)url
                              enable:(BOOL)enable
                              isEdit:(BOOL)isEdit {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _initialHost = [host copy];
    _initialUri = [uri copy];
    _initialUrl = [url copy];
    _initialEnable = enable;
    _isEdit = isEdit;
    self.modalPresentationStyle = UIModalPresentationFormSheet;
  }
  return self;
}

- (UITextField *)_outlinedField:(NSString *)placeholder {
  UITextField *tf = [UITextField new];
  tf.placeholder = placeholder;
  tf.font = [UIFont systemFontOfSize:15];
  tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
  tf.autocorrectionType = UITextAutocorrectionTypeNo;
  tf.backgroundColor = AutumnOpsUITheme.surface;
  tf.layer.cornerRadius = 12;
  tf.clipsToBounds = YES;
  [AutumnOpsUITheme applyBorderToLayer:tf.layer color:AutumnOpsUITheme.outlineVariant width:1];
  tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
  tf.leftViewMode = UITextFieldViewModeAlways;
  tf.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
  tf.rightViewMode = UITextFieldViewModeAlways;
  [tf.heightAnchor constraintEqualToConstant:48].active = YES;
  return tf;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  self.title = self.isEdit ? @"编辑跳转" : @"添加跳转";
  self.navigationItem.leftBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(_cancel)];

  UIScrollView *scroll = [UIScrollView new];
  scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  [self.view addSubview:scroll];
  scroll.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
    [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
  ]];

  UIStackView *stack = [UIStackView new];
  stack.axis = UILayoutConstraintAxisVertical;
  stack.spacing = 12;
  [scroll addSubview:stack];
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor constant:20],
    [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:20],
    [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor constant:-20],
    [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-28],
    [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-40],
  ]];

  UILabel *(^lab)(NSString *) = ^UILabel *(NSString *t) {
    UILabel *l = [UILabel new];
    l.text = t;
    l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    l.textColor = AutumnOpsUITheme.onSurface;
    return l;
  };

  _hostField = [self _outlinedField:@"例如 www.example.com"];
  _hostField.text = self.initialHost ?: @"";
  _uriField = [self _outlinedField:@"/"];
  _uriField.text = self.initialUri.length ? self.initialUri : @"/";
  _urlField = [self _outlinedField:@"https://…"];
  _urlField.keyboardType = UIKeyboardTypeURL;
  _urlField.text = self.initialUrl ?: @"";
  _enableRow = [[AutumnOpsSwitchRowView alloc] initWithTitle:@"开启" subtitle:@"关闭后保留规则但不跳转"];
  _enableRow.switchControl.on = self.initialEnable;

  [stack addArrangedSubview:lab(@"域名")];
  [stack addArrangedSubview:_hostField];
  [stack addArrangedSubview:lab(@"资源路径")];
  [stack addArrangedSubview:_uriField];
  [stack addArrangedSubview:lab(@"跳转地址")];
  [stack addArrangedSubview:_urlField];
  [stack addArrangedSubview:_enableRow];

  UIButton *save = [AutumnOpsUIControls buttonWithTitle:@"保存"
                                                  style:AutumnOpsButtonStyleFilled
                                                 target:self
                                                 action:@selector(_save)];
  [stack addArrangedSubview:save];
  [stack setCustomSpacing:20 afterView:_enableRow];
}

- (void)_cancel {
  [self.view endEditing:YES];
  void (^cb)(void) = self.onCancel;
  [self dismissViewControllerAnimated:YES completion:^{
    if (cb) cb();
  }];
}

- (void)_save {
  [self.view endEditing:YES];
  AutumnOpsJumpEditorResult *r = [AutumnOpsJumpEditorResult new];
  r.host = [self.hostField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  r.uri = [self.uriField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  r.url = [self.urlField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  r.enable = self.enableRow.switchControl.on;
  void (^cb)(AutumnOpsJumpEditorResult *) = self.onSave;
  [self dismissViewControllerAnimated:YES completion:^{
    if (cb) cb(r);
  }];
}

@end
