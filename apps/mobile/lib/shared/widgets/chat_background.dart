import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/theme/app_colors.dart';

class ChatBackground extends StatelessWidget {
  final Widget child;

  const ChatBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: AppColors.surfaceMuted),
        ),
        // Placeholder for the KNUST logo repeating background
        Positioned.fill(
          child: Opacity(
            opacity: 0.05,
            child: SvgPicture.network(
              'https://www.svgrepo.com/show/330310/pattern.svg', // generic pattern placeholder
              fit: BoxFit.cover,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
