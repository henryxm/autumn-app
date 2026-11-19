#import "AutumnOpsShareHooks.h"

@implementation AutumnOpsShareHooks
static AutumnOpsShareToChatBlock _toChat;
+ (AutumnOpsShareToChatBlock)toChat { return _toChat; }
+ (void)setToChat:(AutumnOpsShareToChatBlock)toChat { _toChat = [toChat copy]; }
@end
