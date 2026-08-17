import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';

class AimBackground extends StatelessWidget {
  final Widget child;
  final bool showTopHeader;

  const AimBackground({
    super.key,
    required this.child,
    this.showTopHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          const _AimBackdrop(),
          if (showTopHeader)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryForeground,
                      AppColors.primary,
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _AimBackdrop extends StatelessWidget {
  const _AimBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryForeground,
                  AppColors.primaryDark,
                  AppColors.primary,
                  AppColors.primaryForeground,
                ],
                stops: [0.0, 0.34, 0.72, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -90,
            child: _Blob(
              size: 220,
              color: AppColors.textOnPrimary.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: 120,
            left: -100,
            child: _Blob(
              size: 180,
              color: AppColors.textOnPrimary.withValues(alpha: 0.04),
            ),
          ),
          Positioned(
            bottom: 180,
            right: -70,
            child: _Blob(
              size: 160,
              color: AppColors.primaryDark.withValues(alpha: 0.08),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.16,
              child: CustomPaint(
                painter: _AIMPatternPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _AIMPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textOnPrimary.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final glyphPaint = Paint()
      ..color = AppColors.textOnPrimary.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const double step = 90;
    for (double x = -20; x < size.width + 60; x += step) {
      for (double y = 30; y < size.height; y += step) {
        final rect = Rect.fromCenter(center: Offset(x, y), width: 24, height: 18);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          paint,
        );
      }
    }

    final diagonal = Path()
      ..moveTo(size.width * 0.1, size.height * 0.18)
      ..lineTo(size.width * 0.62, size.height * 0.48)
      ..lineTo(size.width * 0.42, size.height * 0.86);
    canvas.drawPath(diagonal, glyphPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}