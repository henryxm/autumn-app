import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpsBackupFile', () {
    test('encode then parse round-trip', () {
      final body = OpsBackupFile.encode(
        wrappedCipher: 'A' * 40,
        baseUrl: 'https://ops.example.com',
        siteId: 'site-1',
        certId: 'cert-1',
        serverFingerprint: 'fp',
      );
      final parsed = OpsBackupFile.parse(body);
      expect(parsed.ok, isTrue);
      expect(parsed.file!.wrapped, 'A' * 40);
      expect(parsed.file!.baseUrl, 'https://ops.example.com');
      expect(parsed.file!.certId, 'cert-1');
    });

    test('accepts legacy raw blob', () {
      final raw = 'B' * 40;
      final parsed = OpsBackupFile.parse(raw);
      expect(parsed.ok, isTrue);
      expect(parsed.file!.wrapped, raw);
      expect(parsed.file!.baseUrl, isNull);
    });

    test('rejects empty', () {
      expect(OpsBackupFile.parse('').ok, isFalse);
    });
  });
}
