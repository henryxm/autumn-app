import 'package:autumn_ops_ui/autumn_ops_ui.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AutumnOpsShellApp());
}

class AutumnOpsShellApp extends StatelessWidget {
  const AutumnOpsShellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Autumn 运维',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const AutumnOpsHome(),
    );
  }
}
