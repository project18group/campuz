import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/app_text_field.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _displayNameController = TextEditingController();
  final _adminCodeController = TextEditingController();
  String? _imagePath;
  bool _isLoading = false;
  bool _showAdminCode = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null && mounted) {
        setState(() => _imagePath = image.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to select that image')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final displayName = _displayNameController.text.trim();
    final adminCode = _adminCodeController.text.trim();

    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthApiService.profileSetup(
        displayName: displayName,
        adminCode: adminCode.isEmpty ? null : adminCode,
      );

      if (mounted) {
        context.go('/home');
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save your profile right now'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Complete Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Make Campuz yours', style: AppTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                'Choose the name classmates will see.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: AppColors.surfaceMuted,
                      backgroundImage: _imagePath == null
                          ? null
                          : FileImage(File(_imagePath!)),
                      child: _imagePath == null
                          ? const Icon(
                              Icons.person_outline,
                              size: 50,
                              color: AppColors.primaryDeep,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: IconButton(
                          iconSize: 18,
                          onPressed: _pickImage,
                          color: Colors.white,
                          icon: const Icon(Icons.add_a_photo_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _displayNameController,
                label: 'Display Name',
                hintText: 'How classmates will see you',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 18),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: _showAdminCode,
                onExpansionChanged: (value) {
                  setState(() => _showAdminCode = value);
                },
                title: Text(
                  'Have a Hub Admin invitation code?',
                  style: AppTextStyles.label,
                ),
                subtitle: Text(
                  'Optional. This grants permission to create hubs.',
                  style: AppTextStyles.caption,
                ),
                children: [
                  AppTextField(
                    controller: _adminCodeController,
                    label: 'Admin Invitation Code',
                    hintText: 'Enter invitation code',
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
              ),
              const SizedBox(height: 36),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : PrimaryButton(
                      text: 'Finish Setup',
                      onPressed: _saveProfile,
                    ),
              if (_imagePath != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Your selected photo is ready. Upload support will be enabled when media storage is connected.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
