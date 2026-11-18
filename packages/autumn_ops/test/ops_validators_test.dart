import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpsValidators.wallIp', () {
    test('accepts ipv4/ipv6/cidr', () {
      expect(OpsValidators.wallIp('192.168.1.10').ok, isTrue);
      expect(OpsValidators.wallIp('192.168.1.0/24').ok, isTrue);
      expect(OpsValidators.wallIp('::1').ok, isTrue);
      expect(OpsValidators.wallIp('2001:db8::1').ok, isTrue);
    });

    test('rejects garbage', () {
      expect(OpsValidators.wallIp('').ok, isFalse);
      expect(OpsValidators.wallIp('abc').ok, isFalse);
      expect(OpsValidators.wallIp('192.168.1.999').ok, isFalse);
      expect(OpsValidators.wallIp('192.168.1.0/99').ok, isFalse);
      expect(OpsValidators.wallIp('1 2 3 4').ok, isFalse);
    });
  });

  group('OpsValidators.siteEndpoint', () {
    test('accepts domain and url', () {
      expect(OpsValidators.siteEndpoint('ops.example.com').ok, isTrue);
      expect(OpsValidators.siteEndpoint('https://ops.example.com').ok, isTrue);
      expect(OpsValidators.siteEndpoint('192.168.1.10:8080').ok, isTrue);
    });

    test('rejects empty and spaces', () {
      expect(OpsValidators.siteEndpoint('').ok, isFalse);
      expect(OpsValidators.siteEndpoint('a b.com').ok, isFalse);
    });
  });

  group('OpsValidators secrets', () {
    test('enroll/claim/clearToken', () {
      expect(OpsValidators.enrollSecret('short').ok, isFalse);
      expect(OpsValidators.enrollSecret('12345678').ok, isTrue);
      expect(OpsValidators.claimSecret('claim-code-xx').ok, isTrue);
      expect(OpsValidators.clearToken('ab').ok, isFalse);
      expect(OpsValidators.clearToken('abcd').ok, isTrue);
      expect(OpsValidators.clearToken('a b').ok, isFalse);
    });
  });
}
