#import "AutumnOpsCrypto.h"

@implementation AutumnOpsKeyPair
@end

@implementation AutumnOpsCrypto

+ (NSString *)stripPem:(NSString *)pem {
  NSMutableString *s = [pem mutableCopy];
  NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"-----BEGIN [^-]+-----|-----END [^-]+-----|\\s"
                                                                      options:0 error:nil];
  [re replaceMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:@""];
  return s;
}

+ (NSData *)_pemToDer:(NSString *)pemOrB64 {
  NSString *b64 = [pemOrB64 containsString:@"BEGIN"] ? [self stripPem:pemOrB64] : [pemOrB64 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  return [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

+ (NSData *)_derLength:(NSUInteger)len {
  if (len < 128) {
    uint8_t b = (uint8_t)len;
    return [NSData dataWithBytes:&b length:1];
  }
  if (len <= 0xff) {
    uint8_t b[2] = { 0x81, (uint8_t)len };
    return [NSData dataWithBytes:b length:2];
  }
  uint8_t b[3] = { 0x82, (uint8_t)((len >> 8) & 0xff), (uint8_t)(len & 0xff) };
  return [NSData dataWithBytes:b length:3];
}

+ (NSData *)_seqTag:(NSData *)content {
  NSMutableData *d = [NSMutableData dataWithBytes:(uint8_t[]){0x30} length:1];
  [d appendData:[self _derLength:content.length]];
  [d appendData:content];
  return d;
}

/// PKCS#1 RSAPublicKey → SubjectPublicKeyInfo (SPKI) for Java/Dart interop.
+ (NSData *)_spkiFromPKCS1Public:(NSData *)pkcs1 {
  static const uint8_t algId[] = {
    0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
  };
  NSMutableData *bit = [NSMutableData dataWithBytes:(uint8_t[]){0x00} length:1];
  [bit appendData:pkcs1];
  NSMutableData *bitString = [NSMutableData dataWithBytes:(uint8_t[]){0x03} length:1];
  [bitString appendData:[self _derLength:bit.length]];
  [bitString appendData:bit];
  NSMutableData *body = [NSMutableData dataWithBytes:algId length:sizeof(algId)];
  [body appendData:bitString];
  return [self _seqTag:body];
}

/// PKCS#1 RSAPrivateKey → PKCS#8 PrivateKeyInfo.
+ (NSData *)_pkcs8FromPKCS1Private:(NSData *)pkcs1 {
  static const uint8_t versionAndAlg[] = {
    0x02, 0x01, 0x00,
    0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
  };
  NSMutableData *oct = [NSMutableData dataWithBytes:(uint8_t[]){0x04} length:1];
  [oct appendData:[self _derLength:pkcs1.length]];
  [oct appendData:pkcs1];
  NSMutableData *body = [NSMutableData dataWithBytes:versionAndAlg length:sizeof(versionAndAlg)];
  [body appendData:oct];
  return [self _seqTag:body];
}

+ (NSString *)_pem:(NSString *)label der:(NSData *)der {
  NSString *b64 = [der base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength | NSDataBase64EncodingEndLineWithLineFeed];
  return [NSString stringWithFormat:@"-----BEGIN %@-----\n%@\n-----END %@-----", label, b64, label];
}

+ (SecKeyRef)_createKeyFromPem:(NSString *)pemOrB64 isPublic:(BOOL)isPublic error:(NSError **)error {
  NSData *der = [self _pemToDer:pemOrB64];
  if (der.length == 0) {
    if (error) *error = [NSError errorWithDomain:@"AutumnOpsCrypto" code:1 userInfo:@{NSLocalizedDescriptionKey: @"invalid key PEM"}];
    return NULL;
  }
  // Try as-is (SPKI / PKCS8), then as PKCS#1.
  NSArray *tries = isPublic
    ? @[ @{ (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA, (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic } ]
    : @[ @{ (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA, (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate } ];
  for (NSDictionary *attrs in tries) {
    CFErrorRef cfErr = NULL;
    SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)der, (__bridge CFDictionaryRef)attrs, &cfErr);
    if (key) {
      if (cfErr) CFRelease(cfErr);
      return key;
    }
    if (cfErr) CFRelease(cfErr);
  }
  if (error) *error = [NSError errorWithDomain:@"AutumnOpsCrypto" code:1 userInfo:@{NSLocalizedDescriptionKey: @"SecKeyCreateWithData failed"}];
  return NULL;
}

+ (nullable AutumnOpsKeyPair *)generateRsa2048:(NSError **)error {
  NSDictionary *attrs = @{
    (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
    (id)kSecAttrKeySizeInBits: @2048,
    (id)kSecPrivateKeyAttrs: @{ (id)kSecAttrIsPermanent: @NO },
  };
  CFErrorRef cfErr = NULL;
  SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attrs, &cfErr);
  if (!privateKey) {
    if (error) *error = CFBridgingRelease(cfErr);
    return nil;
  }
  SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
  CFErrorRef e2 = NULL;
  CFDataRef priRaw = SecKeyCopyExternalRepresentation(privateKey, &e2);
  CFDataRef pubRaw = SecKeyCopyExternalRepresentation(publicKey, &e2);
  CFRelease(privateKey);
  if (publicKey) CFRelease(publicKey);
  if (!priRaw || !pubRaw) {
    if (priRaw) CFRelease(priRaw);
    if (pubRaw) CFRelease(pubRaw);
    if (error) *error = [NSError errorWithDomain:@"AutumnOpsCrypto" code:2 userInfo:@{NSLocalizedDescriptionKey: @"export key failed"}];
    return nil;
  }
  NSData *pkcs8 = [self _pkcs8FromPKCS1Private:(__bridge NSData *)priRaw];
  NSData *spki = [self _spkiFromPKCS1Public:(__bridge NSData *)pubRaw];
  CFRelease(priRaw);
  CFRelease(pubRaw);
  AutumnOpsKeyPair *pair = [AutumnOpsKeyPair new];
  pair.privateKeyPem = [self _pem:@"PRIVATE KEY" der:pkcs8];
  pair.publicKeyPem = [self _pem:@"PUBLIC KEY" der:spki];
  return pair;
}

+ (nullable NSString *)signSha256RsaPem:(NSString *)privateKeyPem payload:(NSString *)payload error:(NSError **)error {
  SecKeyRef key = [self _createKeyFromPem:privateKeyPem isPublic:NO error:error];
  if (!key) return nil;
  NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
  CFErrorRef cfErr = NULL;
  CFDataRef sig = SecKeyCreateSignature(key, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256,
                                        (__bridge CFDataRef)data, &cfErr);
  CFRelease(key);
  if (!sig) {
    if (error) *error = CFBridgingRelease(cfErr);
    return nil;
  }
  NSString *out = [(__bridge NSData *)sig base64EncodedStringWithOptions:0];
  CFRelease(sig);
  return out;
}

+ (nullable NSString *)rsaEncryptToBase64Pem:(NSString *)publicKeyPemOrB64 plain:(NSString *)plain error:(NSError **)error {
  SecKeyRef key = [self _createKeyFromPem:publicKeyPemOrB64 isPublic:YES error:error];
  if (!key) return nil;
  NSData *data = [plain dataUsingEncoding:NSUTF8StringEncoding];
  CFErrorRef cfErr = NULL;
  CFDataRef enc = SecKeyCreateEncryptedData(key, kSecKeyAlgorithmRSAEncryptionPKCS1,
                                            (__bridge CFDataRef)data, &cfErr);
  CFRelease(key);
  if (!enc) {
    if (error) *error = CFBridgingRelease(cfErr);
    return nil;
  }
  NSString *out = [(__bridge NSData *)enc base64EncodedStringWithOptions:0];
  CFRelease(enc);
  return out;
}

+ (NSString *)randomAesKeyBase64 {
  uint8_t buf[16];
  SecRandomCopyBytes(kSecRandomDefault, sizeof(buf), buf);
  return [[NSData dataWithBytes:buf length:sizeof(buf)] base64EncodedStringWithOptions:0];
}

+ (NSString *)randomIvBase64 {
  return [self randomAesKeyBase64];
}

@end
