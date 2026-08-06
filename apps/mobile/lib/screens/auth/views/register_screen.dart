import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/core/mock/mock_data.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/shared/widgets/aim_background.dart';
import 'package:mobile/shared/widgets/app_text_field.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final localPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final username = email;

    if (fullName.isEmpty ||
        email.isEmpty ||
        localPhone.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (localPhone.length != 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must be 9 digits after +233'),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthApiService.register(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: '+233$localPhone',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        MockData.isNewUser = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your email!'),
          ),
        );
        context.go('/otp?username=${Uri.encodeComponent(username)}');
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
          const SnackBar(content: Text('Unable to create account right now')),
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
                    Text(
                      'Create Account',
                      style: AppTextStyles.heading.copyWith(
                        color: AppColors.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Provide the required details in the form fields below.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      hintText: 'Enter your full name',
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hintText: 'example@email.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hintText: '912345678',
                      prefixText: '+233',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: 'Enter password',
                      obscureText: true,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      hintText: 'Confirm password',
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
                              onPressed: _handleSignUp,
                              text: "Create Account",
                            ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/login');
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign In',
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
