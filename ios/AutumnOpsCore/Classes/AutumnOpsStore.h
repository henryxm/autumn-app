#import <Foundation/Foundation.h>
#import "AutumnOpsModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface AutumnOpsStore : NSObject
- (instancetype)initWithFileURL:(NSURL *)fileURL;
@property (nonatomic, readonly) NSURL *fileURL;
- (nullable AutumnOpsCredentialBundle *)load:(NSError * _Nullable * _Nullable)error;
- (BOOL)save:(AutumnOpsCredentialBundle *)bundle error:(NSError * _Nullable * _Nullable)error;
- (BOOL)clear:(NSError * _Nullable * _Nullable)error;
+ (NSString *)exportPassphraseWrapped:(AutumnOpsCredentialBundle *)bundle passphrase:(NSString *)passphrase;
+ (nullable AutumnOpsCredentialBundle *)importPassphraseWrapped:(NSString *)wrappedB64
                                                    passphrase:(NSString *)passphrase
                                                         error:(NSError * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END
