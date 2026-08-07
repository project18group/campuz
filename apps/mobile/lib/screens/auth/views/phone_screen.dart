import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/aim_background.dart';
import 'package:mobile/shared/widgets/app_text_field.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final fullName = _fullNameController.text.trim();
    final local = _phoneController.text.trim();

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }

    if (local.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    if (local.length != 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must be 9 digits after +233'),
        ),
      );
      return;
    }

    final phoneNumber = '+233$local';

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthApiService.requestOtp(
        phoneNumber: phoneNumber,
        fullName: fullName,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        context.go(
          '/otp?phone=${Uri.encodeComponent(phoneNumber)}&fullName=${Uri.encodeComponent(fullName)}',
        );
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
          const SnackBar(content: Text('Unable to send code right now')),
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
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.phone_rounded,
                        color: AppColors.primaryDeep,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Enter Your Phone', style: AppTextStyles.heading),
                    const SizedBox(height: 8),
                    Text(
                      'We\'ll send a verification code to confirm your number.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      hintText: 'Your full name',
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hintText: '201234567',
                      prefixText: '+233',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
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
                              onPressed: _handleContinue,
                              text: 'Send Code',
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
