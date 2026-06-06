import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/app_text_field.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Account', style: AppTextStyles.heading),

            const SizedBox(height: 8),

            Text(
              'Provide the required details in the form fields below.',
              style: AppTextStyles.body,
            ),

            const SizedBox(height: 32),

            const AppTextField(
              label: 'Full Name',
              hintText: 'Enter your full name',
            ),

            const SizedBox(height: 20),

            const AppTextField(
              label: 'Email Address',
              hintText: 'example@email.com',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 20),

            const AppTextField(
              label: 'Phone Number',
              hintText: '0201234567',
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 20),

            const AppTextField(
              label: 'Password',
              hintText: 'Enter password',
              obscureText: true,
            ),

            const SizedBox(height: 20),

            const AppTextField(
              label: 'Confirm Password',
              hintText: 'Confirm password',
              obscureText: true,
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,

              child: PrimaryButton(
                onPressed: () {
                  context.go("/otp");
                },
                text: "Create Account",
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: RichText(
                text: TextSpan(
                  text: 'Already have an account? ',
                  style: AppTextStyles.body,
                  children: [
                    TextSpan(
                      text: 'Sign In',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.surface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
