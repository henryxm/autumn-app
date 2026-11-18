import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpsEndpoint.resolve', () {
    test('explicit http/https — no auto scheme join', () {
      final http = OpsEndpoint.resolve('http://192.168.1.10:8080/');
      expect(http.kind, OpsEndpointKind.explicit);
      expect(http.candidates, ['http://192.168.1.10:8080']);

      final https = OpsEndpoint.resolve('https://ops.example.com');
      expect(https.kind, OpsEndpointKind.explicit);
      expect(https.candidates, ['https://ops.example.com']);
    });

    test('domain prefers https then http', () {
      final plan = OpsEndpoint.resolve('ops.example.com');
      expect(plan.kind, OpsEndpointKind.domain);
      expect(plan.candidates, [
        'https://ops.example.com',
        'http://ops.example.com',
      ]);
    });

    test('domain with port and path', () {
      final plan = OpsEndpoint.resolve('ops.example.com:8443/app');
      expect(plan.kind, OpsEndpointKind.domain);
      expect(plan.candidates, [
        'https://ops.example.com:8443/app',
        'http://ops.example.com:8443/app',
      ]);
    });

    test('IPv4 incl. private uses http only', () {
      for (final raw in [
        '192.168.1.10',
        '10.0.0.1',
        '172.16.5.9',
        '127.0.0.1',
        '192.168.1.10:8080',
      ]) {
        final plan = OpsEndpoint.resolve(raw);
        expect(plan.kind, OpsEndpointKind.ip, reason: raw);
        expect(plan.candidates.length, 1, reason: raw);
        expect(plan.candidates.first.startsWith('http://'), isTrue, reason: raw);
        expect(plan.candidates.first.contains('https://'), isFalse, reason: raw);
      }
    });

    test('IPv6 bracketed uses http', () {
      final plan = OpsEndpoint.resolve('[fd00::1]:8080');
      expect(plan.kind, OpsEndpointKind.ip);
      expect(plan.candidates, ['http://[fd00::1]:8080']);
    });

    test('empty input yields no candidates', () {
      expect(OpsEndpoint.resolve('').isEmpty, isTrue);
      expect(OpsEndpoint.resolve('   ').isEmpty, isTrue);
    });
  });

  group('OpsEndpoint.isIpLiteral', () {
    test('ipv4 / ipv6', () {
      expect(OpsEndpoint.isIpLiteral('192.168.0.1'), isTrue);
      expect(OpsEndpoint.isIpLiteral('::1'), isTrue);
      expect(OpsEndpoint.isIpLiteral('[::1]'), isTrue);
      expect(OpsEndpoint.isIpLiteral('example.com'), isFalse);
      expect(OpsEndpoint.isIpLiteral('localhost'), isFalse);
    });
  });
}
