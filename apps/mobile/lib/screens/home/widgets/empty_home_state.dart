import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

const homeEmptyHeroTag = 'home-empty-hero';

class EmptyHomeState extends StatelessWidget {
  const EmptyHomeState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: homeEmptyHeroTag,
              child: Material(
                color: Colors.transparent,
                child: SvgPicture.asset(
                  'assets/images/firsttime_home.svg',
                  height: 240,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Welcome to Campuz',
              textAlign: TextAlign.center,
              style: AppTextStyles.display.copyWith(
                color: AppColors.primaryDeep,
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No chats yet?',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Join a hub to start receiving messages.\nIf you are creating the space for your class, make a hub to start sharing updates.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: PrimaryButton(
                text: 'Join Hub',
                onPressed: () => context.push('/join-hub'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => context.push('/create-hub'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDeep,
                  side: BorderSide(
                    color: AppColors.primaryDeep,
                    width: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Create Hub',
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}