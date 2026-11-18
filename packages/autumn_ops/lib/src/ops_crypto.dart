import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';

/// RSA/AES helpers for Autumn ops channel (PKCS1, SHA256withRSA).
class OpsCrypto {
  OpsCrypto._();

  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRsa2048() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  static String publicKeyToPem(RSAPublicKey key) =>
      CryptoUtils.encodeRSAPublicKeyToPem(key);

  static String privateKeyToPem(RSAPrivateKey key) =>
      CryptoUtils.encodeRSAPrivateKeyToPem(key);

  static String stripPem(String pem) {
    return pem
        .replaceAll(RegExp(r'-----BEGIN [^-]+-----'), '')
        .replaceAll(RegExp(r'-----END [^-]+-----'), '')
        .replaceAll(RegExp(r'\s'), '');
  }

  static RSAPublicKey loadPublicKey(String pemOrB64) {
    final cleaned = pemOrB64.contains('BEGIN')
        ? pemOrB64
        : '-----BEGIN PUBLIC KEY-----\n$pemOrB64\n-----END PUBLIC KEY-----';
    return CryptoUtils.rsaPublicKeyFromPem(cleaned);
  }

  static RSAPrivateKey loadPrivateKey(String pemOrB64) {
    if (pemOrB64.contains('BEGIN')) {
      return CryptoUtils.rsaPrivateKeyFromPem(pemOrB64);
    }
    final wrapped =
        '-----BEGIN PRIVATE KEY-----\n$pemOrB64\n-----END PRIVATE KEY-----';
    return CryptoUtils.rsaPrivateKeyFromPem(wrapped);
  }

  static String signSha256Rsa(RSAPrivateKey privateKey, String payload) {
    final signer = Signer('SHA-256/RSA')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final sig = signer.generateSignature(Uint8List.fromList(utf8.encode(payload)))
        as RSASignature;
    return base64Encode(sig.bytes);
  }

  static String rsaEncryptToBase64(RSAPublicKey publicKey, String plain) {
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final input = Uint8List.fromList(utf8.encode(plain));
    final out = _process(cipher, input);
    return base64Encode(out);
  }

  static String randomAesKeyBase64({int bytes = 16}) {
    final rnd = Random.secure();
    final raw = Uint8List.fromList(List.generate(bytes, (_) => rnd.nextInt(256)));
    return base64Encode(raw);
  }

  static String randomIvBase64({int bytes = 16}) {
    return randomAesKeyBase64(bytes: bytes);
  }

  static Uint8List _process(AsymmetricBlockCipher cipher, Uint8List input) {
    final out = BytesBuilder(copy: false);
    var offset = 0;
    while (offset < input.length) {
      final len = (offset + cipher.inputBlockSize <= input.length)
          ? cipher.inputBlockSize
          : input.length - offset;
      out.add(cipher.process(Uint8List.fromList(input.sublist(offset, offset + len))));
      offset += len;
    }
    return out.toBytes();
  }
}
