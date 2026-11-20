import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter_test/flutter_test.dart'; // flutter_test from package deps

void main() {
  test('shareUrlForBase', () {
    expect(
      AutumnOpsDiscover.shareUrlForBase('https://a.example.com/'),
      'https://a.example.com/ops/discover',
    );
  });

  test('tryParseBaseUrl discover path', () {
    expect(
      AutumnOpsDiscover.tryParseBaseUrl('https://a.example.com/ops/discover'),
      'https://a.example.com',
    );
    expect(
      AutumnOpsDiscover.tryParseBaseUrl(
        'https://a.example.com/ops/discover?x=1',
      ),
      'https://a.example.com',
    );
  });

  test('tryParseBaseUrl query flag', () {
    expect(
      AutumnOpsDiscover.tryParseBaseUrl('https://a.example.com/?autumn_ops=1'),
      'https://a.example.com',
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

}
