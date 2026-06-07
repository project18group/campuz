import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';

class AppFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  const AppFab({super.key, required this.onPressed, this.icon = Icons.add});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}
