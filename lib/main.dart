import 'package:flutter/material.dart';

void main() {
  runApp(const OnThisDayApp());
}

class OnThisDayApp extends StatelessWidget {
  const OnThisDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On This Day',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('On This Day')));
  }
}
