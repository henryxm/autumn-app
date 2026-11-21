import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shareUrlForBase', () {
    expect(
      AutumnOpsDiscover.shareUrlForBase('https://a.example.com/'),
      'https://a.example.com/autumn/ops/discover',
    );
  });

  test('tryParseBaseUrl discover path', () {
    expect(
      AutumnOpsDiscover.tryParseBaseUrl('https://a.example.com/autumn/ops/discover'),
      'https://a.example.com',
    );
    expect(
      AutumnOpsDiscover.tryParseBaseUrl(
        'https://a.example.com/autumn/ops/discover?x=1',
      ),
      'https://a.example.com',
    );
  });

  test('tryParseBaseUrl ignores old /ops/discover path', () {
    expect(
      AutumnOpsDiscover.tryParseBaseUrl('https://a.example.com/ops/discover'),
      isNull,
    );
  });

  test('tryParseBaseUrl ignores query flag', () {
    expect(
      AutumnOpsDiscover.tryParseBaseUrl('https://a.example.com/?autumn_ops=1'),
      isNull,
    );
  });

  test('tryParseBaseUrl ignores bare https', () {
    expect(
      AutumnOpsDiscover.tryParseBaseUrl('https://a.example.com/'),
      isNull,
    );
  });

  test('tryParseBaseUrl custom-scheme deep link', () {
    expect(
      AutumnOpsDiscover.tryParseBaseUrl(
        'myapp://vc/autumnops?base=https%3A%2F%2Fa.example.com',
      ),
      'https://a.example.com',
    );
  });

  test('tryParseBaseUrl forceHttpBase for known intent', () {
    expect(
      AutumnOpsDiscover.tryParseBaseUrl(
        'https://a.example.com/admin',
        forceHttpBase: true,
      ),
      'https://a.example.com/admin',
    );
  });
}
