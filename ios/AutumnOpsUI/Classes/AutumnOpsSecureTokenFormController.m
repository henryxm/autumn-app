#import "AutumnOpsSecureTokenFormController.h"
#import "AutumnOpsUIControls.h"
#import "AutumnOpsUITheme.h"

@interface AutumnOpsSecureTokenFormController ()
@property (nonatomic, copy) NSString *formTitle;
@property (nonatomic, copy) NSString *reason;
@property (nonatomic, copy) NSString *fieldLabel;
@property (nonatomic, copy, nullable) NSString *fieldHelper;
@property (nonatomic, copy) NSString *confirmLabel;
@property (nonatomic, copy, nullable) NSString *initialText;
@property (nonatomic, strong) UITextField *field;
@end

@implementation AutumnOpsSecureTokenFormController

- (instancetype)initWithTitle:(NSString *)title
                       reason:(NSString *)reason
                   fieldLabel:(NSString *)fieldLabel
                  fieldHelper:(NSString *)fieldHelper
                 confirmLabel:(NSString *)confirmLabel
                  initialText:(NSString *)initialText {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _formTitle = [title copy];
    _reason = [reason copy];
    _fieldLabel = [fieldLabel copy];
    _fieldHelper = [fieldHelper copy];
    _confirmLabel = [confirmLabel copy];
    _initialText = [initialText copy];
    self.modalPresentationStyle = UIModalPresentationFormSheet;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  self.title = self.formTitle;
  self.navigationItem.leftBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(_cancel)];

  UIScrollView *scroll = [UIScrollView new];
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

  UILabel *reason = [UILabel new];
  reason.numberOfLines = 0;
  reason.font = [UIFont systemFontOfSize:13];
  reason.textColor = AutumnOpsUITheme.onSurfaceVariant;
  reason.text = self.reason;
  [stack addArrangedSubview:reason];

  UILabel *lab = [UILabel new];
  lab.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
  lab.textColor = AutumnOpsUITheme.onSurface;
  lab.text = self.fieldLabel;
  [stack addArrangedSubview:lab];

  _field = [UITextField new];
  _field.secureTextEntry = YES;
  _field.borderStyle = UITextBorderStyleNone;
  _field.font = [UIFont systemFontOfSize:15];
  _field.text = self.initialText;
  _field.backgroundColor = AutumnOpsUITheme.surface;
  _field.layer.cornerRadius = 12;
  _field.clipsToBounds = YES;
  [AutumnOpsUITheme applyBorderToLayer:_field.layer color:AutumnOpsUITheme.outlineVariant width:1];
  _field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
  _field.leftViewMode = UITextFieldViewModeAlways;
  _field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
  _field.rightViewMode = UITextFieldViewModeAlways;
  [_field.heightAnchor constraintEqualToConstant:48].active = YES;
  [stack addArrangedSubview:_field];

  if (self.fieldHelper.length) {
    UILabel *help = [UILabel new];
    help.numberOfLines = 0;
    help.font = [UIFont systemFontOfSize:12];
    help.textColor = AutumnOpsUITheme.onSurfaceVariant;
    help.text = self.fieldHelper;
    [stack addArrangedSubview:help];
  }

  UIButton *confirm = [AutumnOpsUIControls buttonWithTitle:self.confirmLabel
                                                     style:AutumnOpsButtonStyleFilled
                                                    target:self
                                                    action:@selector(_confirm)];
  [stack addArrangedSubview:confirm];
  [stack setCustomSpacing:20 afterView:_field];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self.field becomeFirstResponder];
}

- (void)_cancel {
  [self.view endEditing:YES];
  if (self.onResult) self.onResult(nil);
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)_confirm {
  [self.view endEditing:YES];
  NSString *t = [self.field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  void (^done)(NSString *) = self.onResult;
  [self dismissViewControllerAnimated:YES completion:^{
    if (done) done(t);
  }];
}

@end
