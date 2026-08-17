import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/screens/ai/views/ai_screen.dart';
import 'package:mobile/screens/home/views/home_screen.dart';
import 'package:mobile/screens/profile/views/profile_screen.dart';
import 'package:mobile/screens/sessions/views/sessions_screen.dart';
import 'package:mobile/shared/widgets/patterned_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _keyShowSessionBadges = 'settings_show_session_badges';
  static const _tabRoutes = ['/home', '/sessions', '/ai', '/profile'];

  late final PageController _pageController;

  int _getCurrentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/sessions')) return 1;
    if (location.startsWith('/ai')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  Future<bool> _showSessionBadges() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowSessionBadges) ?? true;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentIndex = _getCurrentIndex(context);
      if (_pageController.hasClients &&
          _pageController.page?.round() != currentIndex) {
        _pageController.jumpToPage(currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(BuildContext context, int index) {
    if (index < 0 || index >= _tabRoutes.length) {
      return;
    }

    if (_getCurrentIndex(context) == index) {
      if (index == 0) {
        HomeScreen.homeKey.currentState?.refreshHome();
      }
      return;
    }

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    context.go(_tabRoutes[index]);
  }

  void _onPageChanged(BuildContext context, int index) {
    if (index < 0 || index >= _tabRoutes.length) {
      return;
    }

    if (GoRouterState.of(context).uri.toString() != _tabRoutes[index]) {
      context.go(_tabRoutes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _showSessionBadges(),
      builder: (context, snapshot) {
        final showSessionBadges = snapshot.data ?? true;
        final currentIndex = _getCurrentIndex(context);

        return PatternedBackground(
          child: Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
            body: PageView(
              controller: _pageController,
              onPageChanged: (index) => _onPageChanged(context, index),
              children: [
                HomeScreen(key: HomeScreen.homeKey),
                const SessionsScreen(),
                const AiScreen(),
                const ProfileScreen(),
              ],
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(0),
                ),
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(0),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: SafeArea(
                    child: BottomNavigationBar(
                      currentIndex: currentIndex,
                      onTap: (index) => _onTabTapped(context, index),
                      selectedItemColor: AppColors.primaryForeground,
                      unselectedItemColor: AppColors.textSecondary,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      type: BottomNavigationBarType.fixed,
                      showUnselectedLabels: false,
                      selectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      items: [
                        BottomNavigationBarItem(
                          icon: _buildIcon(Icons.forum_outlined, false),
                          activeIcon: _buildIcon(Icons.forum, true),
                          label: "Hubs",
                        ),
                        BottomNavigationBarItem(
                          icon: _buildSessionIcon(false, showSessionBadges),
                          activeIcon: _buildSessionIcon(
                            true,
                            showSessionBadges,
                          ),
                          label: "Sessions",
                        ),
                        BottomNavigationBarItem(
                          icon: _buildIcon(Icons.smart_toy_outlined, false),
                          activeIcon: _buildIcon(Icons.smart_toy, true),
                          label: "AI Assist",
                        ),
                        BottomNavigationBarItem(
                          icon: _buildIcon(Icons.person_outline, false),
                          activeIcon: _buildIcon(Icons.person, true),
                          label: "Profile",
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon(IconData icon, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: isActive ? 16.0 : 8.0,
        vertical: 8.0,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primaryForeground.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon),
    );
  }

  Widget _buildSessionIcon(bool isActive, bool showBadge) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildIcon(Icons.grid_view_rounded, isActive),
        if (showBadge)
          Positioned(
            right: 0,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '4',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
