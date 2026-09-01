import 'package:flutter/material.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/app_colors.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/services/auth_api_service.dart';

import 'package:mobile/core/services/push_notification_service.dart';

// Global theme notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize push notifications (handles Firebase Core init as well)
  await PushNotificationService.initialize();

  // Load saved theme mode from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('settings_dark_mode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // Sync any offline messages in the background
  AuthApiService.syncOfflineQueue().catchError((_) {});

  runApp(const CampuzApp());
}

class CampuzApp extends StatelessWidget {
  const CampuzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        // Build the theme based on the current mode
        if (currentMode == ThemeMode.light) {
          AppColors.setLightTheme();
        } else {
          AppColors.setDarkTheme();
        }

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          routerConfig: appRouter,
        );
      },
    );
  }
}
