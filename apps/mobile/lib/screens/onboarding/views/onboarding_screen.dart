import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/onboarding/data/onboarding_data.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  final ValueNotifier<int> currentPage = ValueNotifier(0);

  @override
  void dispose() {
    _pageController.dispose();
    currentPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            //Skip
            Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    //jump directly to last onboarding
                    _pageController.animateToPage(
                      onboardingItems.length - 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Text(
                    'Skip',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingItems.length,
                onPageChanged: (index) {
                  currentPage.value = index;
                },
                itemBuilder: (context, index) {
                  final Item = onboardingItems[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: SizedBox(
                            height: size.height * .35,
                            child: SvgPicture.asset(
                              Item.image,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        // add some space
                        const SizedBox(height: 32),

                        Text(
                          Item.title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display,
                        ),

                        //space
                        const SizedBox(height: 16),

                        Text(
                          Item.description,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ValueListenableBuilder(
              valueListenable: currentPage,
              builder: (_, index, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(onboardingItems.length, (dotIndex) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == dotIndex ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: index == dotIndex
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ValueListenableBuilder(
                valueListenable: currentPage,
                builder: (_, index, _) {
                  final isLastPage = index == onboardingItems.length - 1;

                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: PrimaryButton(
                      onPressed: () {
                        if (isLastPage) {
                          //Navigate to register
                          context.go("/register-onboard");
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      text: "Next",
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
