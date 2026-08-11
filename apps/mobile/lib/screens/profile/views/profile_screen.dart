import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // currentUser() reads the stored token and refreshes it on a 401.
      final user = await AuthApiService.currentUser();
      if (!mounted) {
        return;
      }

      setState(() {
        _userData = user;
        _isLoading = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load profile right now')),
      );
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await AuthApiService.signOut();

    if (context.mounted) {
      context.go('/phone');
    }
  }

  String _defaultAvatarUrl(Map<String, dynamic>? user) {
    final profile = user?['profile'] as Map<String, dynamic>? ?? const {};
    final seed = (profile['display_name'] as String? ?? '').trim().isNotEmpty
        ? (profile['display_name'] as String).trim()
        : ((profile['full_name'] as String? ?? '').trim().isNotEmpty
            ? (profile['full_name'] as String).trim()
            : 'Campuz Student');
    return Uri.https('api.dicebear.com', '/10.x/initials/svg', {
      'seed': seed,
    }).toString();
  }

  Future<void> _changeAvatar() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (image == null) return;
      await AuthApiService.profileSetup(
        avatarFile: File(image.path),
      );
      if (!mounted) return;
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update your photo right now')),
      );
    }
  }

  Future<void> _removeAvatar() async {
    try {
      await AuthApiService.profileSetup(removeAvatar: true);
      if (!mounted) return;
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo removed')),
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove your photo right now')),
      );
    }
  }

  void _showAvatarActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Change photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changeAvatar();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeAvatar();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _userData;
    final profile = user?['profile'] as Map<String, dynamic>?;
    final fullName = (profile?['full_name'] as String? ?? '').trim();
    final phoneNumber = (profile?['phone_number'] as String? ?? '').trim();
    final profileDisplayName = (profile?['display_name'] as String? ?? '')
        .trim();
    final avatarUrl = (profile?['avatar_url'] as String? ?? '').trim();
    final avatarImage = avatarUrl.isNotEmpty
        ? NetworkImage(avatarUrl)
        : NetworkImage(_defaultAvatarUrl(user));
    final displayName = profileDisplayName.isNotEmpty
        ? profileDisplayName
        : (fullName.isNotEmpty ? fullName : 'Your profile');

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Container(
        color: AppColors.background,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDeep, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                        child: Column(
                          children: [
                          GestureDetector(
                            onTap: _showAvatarActions,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 54,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  backgroundImage: avatarImage,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            displayName,
                            style: AppTextStyles.heading.copyWith(
                              color: Colors.white,
                              fontSize: 22,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (fullName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              fullName,
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (phoneNumber.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              phoneNumber,
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: _showAvatarActions,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.manage_accounts_outlined),
                            label: const Text('Manage photo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _profileTile(
                            icon: Icons.school_outlined,
                            title: "Academic Info",
                            subtitle: "Verified account",
                            onTap: () {},
                          ),
                          const Divider(height: 1, indent: 60),
                          _profileTile(
                            icon: Icons.campaign_outlined,
                            title: "Broadcasts",
                            onTap: () => context.push('/broadcasts'),
                          ),
                          const Divider(height: 1, indent: 60),
                          _profileTile(
                            icon: Icons.folder_outlined,
                            title: "Resource Gallery",
                            onTap: () => context.push('/resources'),
                          ),
                          const Divider(height: 1, indent: 60),
                          _profileTile(
                            icon: Icons.assignment_outlined,
                            title: "Tasks & Assignments",
                            onTap: () => context.push('/tasks'),
                          ),
                          const Divider(height: 1, indent: 60),
                          _profileTile(
                            icon: Icons.calendar_month_outlined,
                            title: "Calendar Sync",
                            onTap: () => context.push('/calendar'),
                          ),
                          const Divider(height: 1, indent: 60),
                          _profileTile(
                            icon: Icons.settings_outlined,
                            title: "Settings",
                            onTap: () {},
                          ),
                          const Divider(height: 1, indent: 60),
                          _profileTile(
                            icon: Icons.exit_to_app_outlined,
                            title: "Sign Out",
                            destructive: true,
                            onTap: () => _handleSignOut(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    String? subtitle,
    bool destructive = false,
  }) {
    final color = destructive ? AppColors.error : AppColors.primaryDeep;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: AppTextStyles.label.copyWith(
          color: destructive ? AppColors.error : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: destructive ? AppColors.error : AppColors.textSecondary,
      ),
    );
  }
}
