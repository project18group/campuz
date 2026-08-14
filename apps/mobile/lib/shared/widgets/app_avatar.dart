import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/theme/app_colors.dart';

class AppAvatar extends StatelessWidget {
  final String avatarUrl;
  final String fallbackName;
  final double size;

  const AppAvatar({
    super.key,
    required this.avatarUrl,
    required this.fallbackName,
    this.size = 50.0,
  });

  String _getFallbackUrl() {
    final seed = fallbackName.isEmpty ? 'User' : fallbackName;
    return 'https://api.dicebear.com/7.x/initials/svg?seed=${Uri.encodeComponent(seed)}';
  }

  @override
  Widget build(BuildContext context) {
    String url = avatarUrl;
    
    // Handle old format if it's cached or present
    if (url.startsWith('seed:')) {
      final seed = url.substring(5);
      url = 'https://api.dicebear.com/7.x/adventurer/svg?seed=${Uri.encodeComponent(seed)}';
    } else if (url.isEmpty) {
      url = _getFallbackUrl();
    }

    if (url.endsWith('.svg') || url.contains('/svg')) {
      return ClipOval(
        child: Container(
          width: size,
          height: size,
          color: AppColors.surfaceMuted,
          child: SvgPicture.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholderBuilder: (BuildContext context) => Center(
              child: Icon(
                Icons.person_rounded,
                color: AppColors.primary.withValues(alpha: 0.35),
                size: size * 0.42,
              ),
            ),
          ),
        ),
      );
    } else {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.surfaceMuted,
        backgroundImage: NetworkImage(url),
      );
    }
  }
}
