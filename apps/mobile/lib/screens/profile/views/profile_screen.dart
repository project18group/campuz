import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _handleSignOut(BuildContext context) async {
    // TODO: Connect to Django REST Framework
    // POST /api/auth/logout/ (invalidate token/session on server)
    // Clear locally stored JWT / session token

    if (context.mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with data fetched from Django REST API (GET /api/users/me/)
    const String email = 'user@campuz.edu';
    const String fullName = 'Alice Smith';
    const String username = '@alice_s';
    const String? avatarPath = null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Card
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                    backgroundImage: avatarPath != null && File(avatarPath).existsSync()
                        ? FileImage(File(avatarPath))
                        : null,
                    child: avatarPath == null || !File(avatarPath).existsSync()
                        ? const Icon(Icons.person, size: 60, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fullName,
                    style: AppTextStyles.heading.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    username,
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Options List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.school_outlined, color: AppColors.primary),
                    title: const Text("Academic Info"),
                    subtitle: const Text("Computer Science, Level 300"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
                    title: const Text("Settings"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.exit_to_app_outlined, color: Colors.red),
                    title: const Text("Sign Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () => _handleSignOut(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
