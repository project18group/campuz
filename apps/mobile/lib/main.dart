import 'package:flutter/material.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/theme/app_theme.dart';

void main() {
  runApp(const CampuzApp());
}

class CampuzApp extends StatelessWidget {
  const CampuzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: true,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
