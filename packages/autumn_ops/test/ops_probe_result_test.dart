import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpsProbeResult defaults discoverEnabled when absent', () {
    final r = OpsProbeResult.fromJson({
      'autumn': true,
      'opsCert': 'pending',
      'adminIpEnable': false,
      'enrollAvailable': true,
    });
    expect(r.discoverEnabled, isTrue);
  });

  test('OpsProbeResult parses discoverEnabled false', () {
    final r = OpsProbeResult.fromJson({
      'autumn': true,
      'opsCert': 'ready',
      'adminIpEnable': true,
      'enrollAvailable': false,
      'discoverEnabled': false,
    });
    expect(r.discoverEnabled, isFalse);
  });
}
