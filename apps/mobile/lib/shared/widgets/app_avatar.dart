import 'package:avatar_plus/avatar_plus.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.startsWith('seed:')) {
      return ClipOval(
        child: AvatarPlus(
          avatarUrl.substring(5),
          height: size,
          width: size,
        ),
      );
    } else if (avatarUrl.isEmpty) {
      return ClipOval(
        child: AvatarPlus(
          fallbackName.isEmpty ? 'User' : fallbackName,
          height: size,
          width: size,
        ),
      );
    } else {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.surfaceMuted,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
  }
}
