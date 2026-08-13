import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  bool _isLoading = false;
  bool _showAdminCode = false;
  String _selectedSeed = 'Felix'; // Default avatar

  final List<String> _defaultSeeds = [
    'Felix',
    'Aneka',
    'Molly',
    'Jude',
    'Tinkerbell',
    'Lucky',
    'Leo',
    'Mia',
    'Oliver',
    'Chloe'
  ];

  String _getAvatarUrl(String seed) {
    return 'https://api.dicebear.com/7.x/adventurer/svg?seed=${Uri.encodeComponent(seed)}';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _adminCodeController.dispose();
    super.dispose();
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
        avatarUrl: _getAvatarUrl(_selectedSeed),
        removeAvatar: false,
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
      body: _isLoading 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text('Creating your account...',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 20,
                        color: AppColors.primaryDeep,
                      )),
                  const SizedBox(height: 8),
                  Text('Please wait a moment.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Make Campuz yours', style: AppTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                'Choose your default avatar and display name.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: SvgPicture.network(
                    _getAvatarUrl(_selectedSeed),
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    placeholderBuilder: (BuildContext context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select an Avatar',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _defaultSeeds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final seed = _defaultSeeds[index];
                    final isSelected = seed == _selectedSeed;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedSeed = seed);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: AppColors.primary, width: 3)
                              : null,
                        ),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: SvgPicture.network(
                            _getAvatarUrl(seed),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholderBuilder: (BuildContext context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
              PrimaryButton(
                text: 'Finish Setup',
                onPressed: _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
