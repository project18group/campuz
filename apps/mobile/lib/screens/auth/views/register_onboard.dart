import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class RegisterOnboard extends StatelessWidget {
  const RegisterOnboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              SizedBox(
                height: 220,
                child: SvgPicture.asset('assets/images/create_account.svg'),
              ),

              const SizedBox(height: 40),

              Text('Create Account', style: AppTextStyles.heading),

              const SizedBox(height: 12),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  children:[

                    TextSpan(
                      
                      text:
                          'Read our Privacy Policies. By tapping "Continue" you agree to our ',
                          
                    ),

                    TextSpan(text: 'Terms of Service.'),
                  ],
                ),
              ),

              const Spacer(),

              PrimaryButton(
                text: "Continue",
                onPressed: () {
                  context.go("/register");
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
