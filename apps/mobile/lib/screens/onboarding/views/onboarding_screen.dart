import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/onboarding_storage.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/onboarding/data/onboarding_data.dart';
import 'package:mobile/shared/widgets/aim_background.dart';
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
      backgroundColor: Colors.transparent,
      body: AimBackground(
        showTopHeader: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _pageController.animateToPage(
                        onboardingItems.length - 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Text(
                      'Skip',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnPrimary,
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
                    final item = onboardingItems[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
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
                                  height: size.height * .30,
                                  child: SvgPicture.asset(
                                    item.image,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  item.title,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.display.copyWith(
                                    fontSize: 30,
                                    color: AppColors.primaryDeep,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  item.description,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
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
                              ? AppColors.textOnPrimary
                              : AppColors.textOnPrimary.withValues(alpha: 0.35),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                            // Capture the router before the async gap so the
                            // BuildContext is not used across an await boundary.
                            final router = GoRouter.of(context);
                            OnboardingStorage.markCompleted().then((_) {
                              if (mounted) router.go("/phone");
                            });
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        text: "Tap to Continue",
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
