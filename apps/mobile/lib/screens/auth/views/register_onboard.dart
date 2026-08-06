import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/aim_background.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class RegisterOnboard extends StatelessWidget {
  const RegisterOnboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AimBackground(
        showTopHeader: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
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
                    children: [
                      SizedBox(
                        height: 220,
                        child: SvgPicture.asset('assets/images/create_account.svg'),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Create Account',
                        style: AppTextStyles.heading.copyWith(
                          color: AppColors.primaryDeep,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          children: const [
                            TextSpan(
                              text:
                                  'Read our Privacy Policies. By tapping "Continue" you agree to our ',
                            ),
                            TextSpan(text: 'Terms of Service.'),
                          ],
                        ),
                      ),
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
      ),
    );
  }
}
