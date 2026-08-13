import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/shared/widgets/patterned_background.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _getCurrentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/ai')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/ai');
        break;
      case 2:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return PatternedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: child,
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: (index) => _onTabTapped(context, index),
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textSecondary,
                backgroundColor: AppColors.surface,
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
    );
  }

  Widget _buildIcon(IconData icon, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: isActive ? 16.0 : 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryDeep.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon),
    );
  }
}
