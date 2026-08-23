import 'package:flutter/material.dart';

import 'core/config/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/app_routes.dart';

void main() {
  runApp(const OnThisDayApp());
}

class OnThisDayApp extends StatelessWidget {
  const OnThisDayApp({super.key});

  static const _router = AppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On This Day',
      theme: AppTheme.light,
      initialRoute: AppRoutes.today,
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}
