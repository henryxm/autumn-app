import 'package:autumn_ops_shell/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shell boots AutumnOpsHome', (WidgetTester tester) async {
    await tester.pumpWidget(const AutumnOpsShellApp());
    await tester.pump();
    expect(find.text('Autumn 运维'), findsOneWidget);
  });
}
