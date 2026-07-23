import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

/// Sprint 8 — animated empty state shown when the user has no joined hubs.
class EmptyHomeState extends StatelessWidget {
  const EmptyHomeState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/firsttime_home.svg',
              height: 220,
            ),
            const SizedBox(height: 32),
            Text(
              "Welcome. No chats yet?\nJoin a hub to start receiving messages. OR are you a rep, create a hub now!",
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            PrimaryButton(
              text: "Join Hub",
              onPressed: () => context.push("/join-hub"),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => context.push("/create-hub"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Create Hub",
                  style: AppTextStyles.title.copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A subtle looping illustration: concentric pulsing circles with a floating
/// chat icon and two orbiting accent dots. Built purely with Flutter — no
/// extra packages or assets required.
class _AnimatedInboxIllustration extends StatefulWidget {
  const _AnimatedInboxIllustration();

  @override
  State<_AnimatedInboxIllustration> createState() =>
      _AnimatedInboxIllustrationState();
}

class _AnimatedInboxIllustrationState extends State<_AnimatedInboxIllustration>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _floatController]),
        builder: (context, _) {
          final pulse = _pulseController.value;
          final float = Curves.easeInOut.transform(_floatController.value);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Two expanding, fading ripple rings.
              _ripple(pulse),
              _ripple((pulse + 0.5) % 1.0),
              // Static soft backdrop circle.
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
              // Orbiting accent dots.
              _orbitDot(pulse * 2 * math.pi, 92, 10,
                  AppColors.accent.withValues(alpha: 0.85)),
              _orbitDot(pulse * 2 * math.pi + math.pi, 92, 7,
                  AppColors.primary.withValues(alpha: 0.55)),
              // Floating icon disc.
              Transform.translate(
                offset: Offset(0, -6 * float + 3),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ripple(double t) {
    final size = 130 + 90 * t;
    final opacity = (1 - t) * 0.25;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: opacity),
          width: 2,
        ),
      ),
    );
  }

  Widget _orbitDot(double angle, double radius, double size, Color color) {
    return Transform.translate(
      offset: Offset(radius * math.cos(angle), radius * math.sin(angle)),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
