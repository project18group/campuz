import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/services/onboarding_storage.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
    _restoreSession();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    // Check if the user has ever completed onboarding.
    final onboardingDone = await OnboardingStorage.hasCompletedOnboarding();

    if (!mounted) return;

    if (!onboardingDone) {
      // First launch ever — show onboarding.
      context.go('/');
      return;
    }

    // Onboarding was completed previously. Check authentication.
    final isValid = await AuthApiService.hasValidSession();

    if (!mounted) return;

    if (isValid) {
      final cachedUser = await AuthApiService.readCachedCurrentUser();
      final hasDisplayName = cachedUser != null && (cachedUser['display_name'] as String? ?? '').trim().isNotEmpty;
      if (hasDisplayName) {
        context.go('/home');
      } else {
        context.go('/profile-setup');
      }
      return;
    }

    // No valid session — route to authentication (phone screen).
    await AuthApiService.signOut();
    if (mounted) {
      context.go('/phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D), Colors.black],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo with animated glow
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Animated glow effect
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(seconds: 2),
                              builder: (context, value, child) {
                                return Container(
                                  width: 160 + (20 * value),
                                  height: 160 + (20 * value),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3 * value,
                                        ),
                                        blurRadius: 60 * value,
                                        spreadRadius: 10 * value,
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onEnd: () {
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                            ),
                            // Logo container
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryForeground,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'C',
                                  style: AppTextStyles.display.copyWith(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textOnPrimary,
                                    letterSpacing: -2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        // Animated loading indicator
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Loading text
                        Text(
                          'Connecting your campus...',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textOnPrimary.withValues(
                              alpha: 0.7,
                            ),
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
