#import <Foundation/Foundation.h>
#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutumnOpsKeyPair : NSObject
@property (nonatomic, copy) NSString *publicKeyPem;
@property (nonatomic, copy) NSString *privateKeyPem;
@end

@interface AutumnOpsCrypto : NSObject

+ (nullable AutumnOpsKeyPair *)generateRsa2048:(NSError * _Nullable * _Nullable)error;
+ (NSString *)stripPem:(NSString *)pem;
+ (nullable NSString *)signSha256RsaPem:(NSString *)privateKeyPem
                               payload:(NSString *)payload
                                 error:(NSError * _Nullable * _Nullable)error;
+ (nullable NSString *)rsaEncryptToBase64Pem:(NSString *)publicKeyPemOrB64
                                      plain:(NSString *)plain
                                      error:(NSError * _Nullable * _Nullable)error;
+ (NSString *)randomAesKeyBase64;
+ (NSString *)randomIvBase64;

@end

NS_ASSUME_NONNULL_END
