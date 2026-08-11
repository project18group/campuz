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
  bool _removeAvatar = false;

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
        setState(() {
          _imagePath = image.path;
          _removeAvatar = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to select that image')),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _imagePath = null;
      _removeAvatar = true;
    });
  }

  String _defaultAvatarUrl() {
    final seed = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : 'Campuz Student';
    return Uri.https('api.dicebear.com', '/10.x/initials/svg', {
      'seed': seed,
    }).toString();
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
        avatarFile: _imagePath == null ? null : File(_imagePath!),
        removeAvatar: _removeAvatar,
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
                          ? NetworkImage(_defaultAvatarUrl())
                          : FileImage(File(_imagePath!)) as ImageProvider,
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
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Change photo'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _removePhoto,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                ],
              ),
              Text(
                'If you do not upload a picture, Campuz will use a network avatar.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
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
                  'Your selected photo will be uploaded to the backend when you finish setup.',
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
