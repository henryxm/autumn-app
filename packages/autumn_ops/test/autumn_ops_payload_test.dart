import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutumnOpsPayload', () {
    test('encode then parse round-trip', () {
      final body = AutumnOpsPayload.encodeJson(
        wrappedCipher: 'A' * 40,
        baseUrl: 'https://ops.example.com',
        siteId: 'site-1',
        certId: 'cert-1',
        serverFingerprint: 'fp',
      );
      final parsed = AutumnOpsPayload.parse(body);
      expect(parsed.ok, isTrue);
      expect(parsed.payload!.wrapped, 'A' * 40);
      expect(parsed.payload!.baseUrl, 'https://ops.example.com');
      expect(parsed.payload!.certId, 'cert-1');
      expect(parsed.payload!.toMap()['kind'], AutumnOpsPayload.kind);
    });

    test('fromMessageMap matches IM AutumnOps fields', () {
      final map = AutumnOpsPayload.toMessageMap(
        wrappedCipher: 'C' * 40,
        baseUrl: 'https://a.example',
        siteId: 's',
        certId: 'c',
      );
      expect(map['kind'], 'autumn-ops');
      expect(map['v'], 1);
      final parsed = AutumnOpsPayload.fromMessageMap(map);
      expect(parsed.ok, isTrue);
      expect(parsed.payload!.wrapped, 'C' * 40);
    });

    test('rejects empty', () {
      expect(AutumnOpsPayload.parse('').ok, isFalse);
    });

    test('rejects non-json', () {
      expect(AutumnOpsPayload.parse('B' * 40).ok, isFalse);
    });

    test('rejects wrong kind', () {
      final parsed = AutumnOpsPayload.fromMessageMap({
        'v': 1,
        'kind': 'other',
        'wrapped': 'A' * 40,
      });
      expect(parsed.ok, isFalse);
    });

    test('rejects missing kind', () {
      final parsed = AutumnOpsPayload.fromMessageMap({
        'v': 1,
        'wrapped': 'A' * 40,
      });
      expect(parsed.ok, isFalse);
    });
  });
}
