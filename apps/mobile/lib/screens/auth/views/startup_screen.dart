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
      final isProfileDone = await AuthApiService.isProfileSetupCompleted();
      if (!mounted) return;

      if (isProfileDone) {
        // WhatsApp behavior: Always route to /home instantly!
        // Background sync user info without blocking
        AuthApiService.currentUser().catchError((_) => <String, dynamic>{});
        context.go('/home');
      } else {
        context.go('/complete-profile');
      }
      return;
    }

    // No valid session — route to authentication (phone screen).
    if (mounted) {
      context.go('/phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFC81822), Color(0xFFB10E15), Color(0xFF8E080E)],
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
                        Image.asset(
                          'assets/images/tekchat_splash.png',
                          width: MediaQuery.sizeOf(context).width * 0.72,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 40),
                        // Animated loading indicator
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
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
