import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';
import 'package:pinput/pinput.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _otpCode = '';
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    if (_otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // TODO: Connect to Django REST authentication
    // POST /api/auth/verify-otp/ with {otp_code}
    // Simulate network delay for presentation realism
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      context.go('/complete-profile');
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: Connect to Django REST authentication
    // POST /api/auth/resend-otp/
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code resent!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            context.go('/register');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text("Verify Your Account", style: AppTextStyles.heading),
              const SizedBox(height: 12),
              Text(
                "Enter the 6-digit verification code sent to your email.",
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 40),
              Center(
                child: Pinput(
                  length: 6,
                  onChanged: (pin) {
                    setState(() {
                      _otpCode = pin;
                    });
                  },
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
