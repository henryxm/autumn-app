#import "AutumnOpsStore.h"

@implementation AutumnOpsStore {
  NSURL *_fileURL;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
  self = [super init];
  if (self) _fileURL = fileURL;
  return self;
}

- (NSURL *)fileURL { return _fileURL; }

- (nullable AutumnOpsCredentialBundle *)load:(NSError **)error {
  NSData *data = [NSData dataWithContentsOfURL:_fileURL options:0 error:error];
  if (!data.length) return nil;
  id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
  if (![obj isKindOfClass:[NSDictionary class]]) return nil;
  return [AutumnOpsCredentialBundle fromJSON:obj];
}

- (BOOL)save:(AutumnOpsCredentialBundle *)bundle error:(NSError **)error {
  NSData *data = [NSJSONSerialization dataWithJSONObject:[bundle toJSON] options:NSJSONWritingPrettyPrinted error:error];
  if (!data) return NO;
  NSURL *dir = _fileURL.URLByDeletingLastPathComponent;
  [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
  return [data writeToURL:_fileURL options:NSDataWritingAtomic error:error];
}

- (BOOL)clear:(NSError **)error {
  if (![[NSFileManager defaultManager] fileExistsAtPath:_fileURL.path]) return YES;
  return [[NSFileManager defaultManager] removeItemAtURL:_fileURL error:error];
}

+ (NSString *)exportPassphraseWrapped:(AutumnOpsCredentialBundle *)bundle passphrase:(NSString *)passphrase {
  NSData *plain = [NSJSONSerialization dataWithJSONObject:[bundle toJSON] options:0 error:nil];
  NSData *key = [passphrase dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableData *out = [NSMutableData dataWithLength:plain.length];
  const uint8_t *p = plain.bytes;
  const uint8_t *k = key.bytes;
  uint8_t *o = out.mutableBytes;
  NSUInteger klen = key.length ?: 1;
  for (NSUInteger i = 0; i < plain.length; i++) {
    o[i] = p[i] ^ k[i % klen];
  }
  return [out base64EncodedStringWithOptions:0];
}

+ (nullable AutumnOpsCredentialBundle *)importPassphraseWrapped:(NSString *)wrappedB64
                                                    passphrase:(NSString *)passphrase
                                                         error:(NSError **)error {
  NSData *raw = [[NSData alloc] initWithBase64EncodedString:wrappedB64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
  if (!raw.length) {
    if (error) *error = [NSError errorWithDomain:@"AutumnOpsStore" code:1 userInfo:@{NSLocalizedDescriptionKey: @"wrapped decode failed"}];
    return nil;
  }
  NSData *key = [passphrase dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableData *plain = [NSMutableData dataWithLength:raw.length];
  const uint8_t *r = raw.bytes;
  const uint8_t *k = key.bytes;
  uint8_t *p = plain.mutableBytes;
  NSUInteger klen = key.length ?: 1;
  for (NSUInteger i = 0; i < raw.length; i++) {
    p[i] = r[i] ^ k[i % klen];
  }
  id obj = [NSJSONSerialization JSONObjectWithData:plain options:0 error:error];
  if (![obj isKindOfClass:[NSDictionary class]]) return nil;
  return [AutumnOpsCredentialBundle fromJSON:obj];
}

@end
