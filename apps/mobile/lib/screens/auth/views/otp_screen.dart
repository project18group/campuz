import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';
import 'package:pinput/pinput.dart';

class OtpScreen extends StatefulWidget {
  /// E.164 phone number the OTP was sent to (e.g. "+233201234567").
  final String? phone;
  final String? fullName;

  const OtpScreen({super.key, this.phone, this.fullName});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _otpCode = '';
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final phone = widget.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing phone number. Please go back and try again.'),
        ),
      );
      return;
    }

    if (_otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await AuthApiService.verifyOtp(
        phoneNumber: phone,
        otpCode: _otpCode,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final isNewUser = response['is_new_user'] as bool? ?? false;
        if (isNewUser) {
          context.go('/complete-profile');
        } else {
          context.go('/home');
        }
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
          const SnackBar(content: Text('Unable to verify code right now')),
        );
      }
    }
  }

  Future<void> _resendCode() async {
    final phone = widget.phone;
    final fullName = widget.fullName;
    if (phone == null ||
        phone.isEmpty ||
        fullName == null ||
        fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing phone number. Please go back and try again.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthApiService.requestOtp(phoneNumber: phone, fullName: fullName);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code resent!')),
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
          const SnackBar(content: Text('Unable to resend code right now')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/phone'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text("Verify Your Number", style: AppTextStyles.heading),
              const SizedBox(height: 12),
              Text(
                "Enter the 6-digit code sent to ${widget.phone ?? 'your phone'}.",
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 40),
              Center(
                child: Pinput(
                  length: 6,
                  showCursor: true,
                  cursor: Container(
                    width: 2,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDeep,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 64,
                    textStyle: AppTextStyles.heading.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 1.4),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                  followingPinTheme: PinTheme(
                    width: 56,
                    height: 64,
                    textStyle: AppTextStyles.heading.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 56,
                    height: 64,
                    textStyle: AppTextStyles.heading.copyWith(
                      color: AppColors.primaryDeep,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primaryDeep,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDeep.withValues(alpha: 0.16),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                  submittedPinTheme: PinTheme(
                    width: 56,
                    height: 64,
                    textStyle: AppTextStyles.heading.copyWith(
                      color: AppColors.primaryDeep,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary, width: 1.4),
                    ),
                  ),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  separatorBuilder: (index) => const SizedBox(width: 12),
                  onCompleted: (pin) => setState(() => _otpCode = pin),
                  onChanged: (pin) => setState(() => _otpCode = pin),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _resendCode,
                  child: const Text("Resend Code"),
                ),
              ),
              const Spacer(),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : PrimaryButton(
                      text: "Verify & Continue",
                      onPressed: _verifyOtp,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
