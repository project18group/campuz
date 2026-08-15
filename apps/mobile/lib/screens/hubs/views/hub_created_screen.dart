import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class HubCreatedScreen extends StatelessWidget {
  const HubCreatedScreen({super.key, this.hub});

  final Map<String, dynamic>? hub;

  @override
  Widget build(BuildContext context) {
    final hubName = (hub?['name'] as String? ?? 'Academic Hub').trim();
    final description = (hub?['description'] as String? ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Academic Hub Ready', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 58,
                  color: AppColors.primaryDeep,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                hubName,
                style: AppTextStyles.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                description.isEmpty
                    ? 'Your hub has been created. Add members and configure invitations from Hub Info.'
                    : description,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PrimaryButton(
                text: 'Return Home',
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}