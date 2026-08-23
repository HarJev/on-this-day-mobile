import 'package:flutter/material.dart';

import 'core/config/app_theme.dart';

void main() {
  runApp(const OnThisDayApp());
}

class OnThisDayApp extends StatelessWidget {
  const OnThisDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On This Day',
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On This Day')),
      body: const SizedBox.expand(),
    );
  }
}
