import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class HubPermissionsScreen extends StatefulWidget {
  const HubPermissionsScreen({super.key, this.hubDraft});

  final Map<String, String>? hubDraft;

  @override
  State<HubPermissionsScreen> createState() => _HubPermissionsScreenState();
}

class _HubPermissionsScreenState extends State<HubPermissionsScreen> {
  bool _isCreating = false;

  Future<void> _createHub() async {
    final name = widget.hubDraft?['name']?.trim() ?? '';
    final description = widget.hubDraft?['description']?.trim() ?? '';

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hub details are missing. Start again.')),
      );
      context.go('/create-hub');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final hub = await AuthApiService.createHub(
        name: name,
        description: description.isEmpty ? null : description,
      );
      if (mounted) {
        context.go('/hub-created', extra: hub);
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to create the hub right now')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: Text('Hub Permissions', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Administrator access',
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: 10),
              Text(
                'You will be the hub owner and administrator. Add more administrators after members join.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: AppColors.primaryDeep,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.hubDraft?['name'] ?? 'Academic Hub',
                            style: AppTextStyles.title,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Only accounts with Hub Admin permission can create hubs.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _isCreating
                  ? const Center(child: CircularProgressIndicator())
                  : PrimaryButton(
                      text: 'Create Hub',
                      onPressed: _createHub,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
