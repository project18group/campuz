import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';

class PatternedBackground extends StatelessWidget {
  final Widget child;

  const PatternedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _BackgroundPainter(),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryForeground.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // Draw the base background color
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw some stylized sweeping curves
    final path1 = Path();
    path1.moveTo(0, size.height * 0.55);
    path1.quadraticBezierTo(
        size.width * 0.4, size.height * 0.4, size.width, size.height * 0.7);
    path1.lineTo(size.width, 0);
    path1.lineTo(0, 0);
    path1.close();

    final paint1 = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path1, paint1);

    final path2 = Path();
    path2.moveTo(0, 0);
    path2.quadraticBezierTo(
        size.width * 0.3, size.height * 0.25, size.width * 0.6, 0);
    path2.close();

    final paint2 = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
