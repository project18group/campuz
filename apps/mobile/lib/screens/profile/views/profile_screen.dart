import 'package:mobile/shared/widgets/app_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/shared/widgets/patterned_background.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _sessions = [
    ('Broadcasts', Icons.campaign_outlined, '/broadcasts'),
    ('Resource Gallery', Icons.folder_outlined, '/resources'),
    ('Tasks & Assignments', Icons.assignment_outlined, '/tasks'),
    ('Calendar Sync', Icons.calendar_month_outlined, '/calendar'),
  ];
  static const _keyShowSessionBadges = 'settings_show_session_badges';

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _hasLoadedCachedProfile = false;
  bool _showSessionBadges = true;

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
    _loadProfile();
    _loadPreferences();
  }

  Future<void> _loadCachedProfile() async {
    final cached = await AuthApiService.readCachedCurrentUser();
    if (!mounted || cached == null) {
      return;
    }

    setState(() {
      _userData = cached;
      _isLoading = false;
      _hasLoadedCachedProfile = true;
    });
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
        _hasLoadedCachedProfile = true;
      });
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      if (!_hasLoadedCachedProfile) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      if (!_hasLoadedCachedProfile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load profile right now')),
        );
      }
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Sign Out', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await AuthApiService.signOut();

    if (context.mounted) {
      context.go('/phone');
    }
  }

  Future<void> _changeAvatar(String seed) async {
    final avatarUrl =
        'https://api.dicebear.com/7.x/adventurer-neutral/svg?seed=${Uri.encodeComponent(seed)}';
    try {
      await AuthApiService.profileSetup(avatarUrl: avatarUrl);
      if (!mounted) return;
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo removed')));
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove your photo right now')),
      );
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }

    setState(() {
      _showSessionBadges = prefs.getBool(_keyShowSessionBadges) ?? true;
    });
  }

  Widget _sessionBadge(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String route,
    required String number,
  }) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  number,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Icon(icon, size: 17, color: AppColors.primaryDeep),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarActions() {
    final avatarSeeds = <String>[];
    var avatarSeedCounter = 0;
    var loadingMoreAvatars = false;

    void appendAvatarSeeds() {
      final nextSeeds = List<String>.generate(12, (index) {
        final number = avatarSeedCounter + index + 1;
        return 'campuz-student-$number';
      });

      avatarSeeds.addAll(nextSeeds);
      avatarSeedCounter += nextSeeds.length;
    }

    appendAvatarSeeds();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void loadMoreAvatars() {
              if (loadingMoreAvatars) return;
              setSheetState(() => loadingMoreAvatars = true);

              Future<void>.delayed(const Duration(milliseconds: 90)).then(
                (_) {
                  if (!sheetContext.mounted) {
                    return;
                  }
                  setSheetState(() {
                    appendAvatarSeeds();
                    loadingMoreAvatars = false;
                  });
                },
              );
            }

            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose an Avatar',
                      style: AppTextStyles.title.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scroll for more student icons.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 96,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.extentAfter < 180) {
                            loadMoreAvatars();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount:
                              avatarSeeds.length + (loadingMoreAvatars ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            if (index >= avatarSeeds.length) {
                              return Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.border,
                                  ),
                                ),
                                child: Icon(
                                  Icons.more_horiz_rounded,
                                  color: AppColors.primaryDeep,
                                ),
                              );
                            }

                            final seed = avatarSeeds[index];
                            final url =
                                'https://api.dicebear.com/7.x/adventurer-neutral/svg?seed=${Uri.encodeComponent(seed)}';

                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _changeAvatar(seed);
                              },
                              child: Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.border.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x12000000),
                                      blurRadius: 12,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: SvgPicture.network(
                                  url,
                                  fit: BoxFit.cover,
                                  placeholderBuilder: (_) => Center(
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.24,
                                      ),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                        ),
                        title: Text(
                          'Remove photo',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _removeAvatar();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
    final displayName = profileDisplayName.isNotEmpty
        ? profileDisplayName
        : (fullName.isNotEmpty ? fullName : 'Your profile');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Profile")),
      body: PatternedBackground(
        child: _isLoading && _userData == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          boxShadow: [
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
                                  AppAvatar(
                                    avatarUrl: avatarUrl,
                                    fallbackName: displayName,
                                    size: 108,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.shadow,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              displayName,
                              style: AppTextStyles.heading.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (fullName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                fullName,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (phoneNumber.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                phoneNumber,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: _showAvatarActions,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                              icon: const Icon(Icons.manage_accounts_outlined),
                              label: const Text('Manage photo'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_showSessionBadges)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sessions',
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _sessionBadge(
                                    context,
                                    label: _sessions[0].$1,
                                    icon: _sessions[0].$2,
                                    route: _sessions[0].$3,
                                    number: '01',
                                  ),
                                  _sessionBadge(
                                    context,
                                    label: _sessions[1].$1,
                                    icon: _sessions[1].$2,
                                    route: _sessions[1].$3,
                                    number: '02',
                                  ),
                                  _sessionBadge(
                                    context,
                                    label: _sessions[2].$1,
                                    icon: _sessions[2].$2,
                                    route: _sessions[2].$3,
                                    number: '03',
                                  ),
                                  _sessionBadge(
                                    context,
                                    label: _sessions[3].$1,
                                    icon: _sessions[3].$2,
                                    route: _sessions[3].$3,
                                    number: '04',
                                  ),
                                ],
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
                          boxShadow: [
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
                              icon: Icons.settings_outlined,
                              title: "Settings",
                              onTap: () async {
                                await context.push('/settings');
                                await _loadPreferences();
                              },
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