import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/core/mock/mock_data.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/shared/widgets/aim_background.dart';
import 'package:mobile/shared/widgets/app_text_field.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // login() persists the token pair to secure storage and AuthSession.
      final response = await AuthApiService.login(
        username: email,
        password: password,
      );
      if (response['access'] == null || response['refresh'] == null) {
        throw const AuthApiException(
          'Login succeeded but tokens were missing from the response.',
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        MockData.isNewUser = false;
        context.go('/home');
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to sign in right now')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: AimBackground(
        showTopHeader: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 96, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                decoration: BoxDecoration(
                  color: AppColors.surface,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: AppColors.primaryDeep,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Sign In', style: AppTextStyles.heading),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back. Continue to your academic workspace.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hintText: 'example@email.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: 'Enter password',
                      obscureText: true,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : PrimaryButton(
                              onPressed: _handleLogin,
                              text: "Tap to Log In",
                            ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/register');
                        },
                        child: RichText(
                          text: TextSpan(
                            text: "Don't have an account? ",
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign Up',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
}
