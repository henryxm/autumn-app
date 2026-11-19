#import "AutumnOpsUIConfig.h"

@implementation AutumnOpsUIConfig

static NSString *_deviceLabel = nil;

+ (NSString *)deviceLabel {
  return _deviceLabel.length ? _deviceLabel : (NSBundle.mainBundle.bundleIdentifier ?: @"ios");
}

+ (void)setDeviceLabel:(NSString *)deviceLabel {
  _deviceLabel = [deviceLabel copy];
}

@end
