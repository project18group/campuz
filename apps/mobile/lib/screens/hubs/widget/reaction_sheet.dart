import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';

class ShowReactionSheet extends StatelessWidget {
  const ShowReactionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: AppColors.primaryDark,
        // color: Theme.of(context).shadowColor,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text('👍', style: TextStyle(fontSize: 28)),
          Text('❤️', style: TextStyle(fontSize: 28)),
          Text('🎉', style: TextStyle(fontSize: 28)),
          Text('😂', style: TextStyle(fontSize: 28)),

          Text('😮', style: TextStyle(fontSize: 28)),
          Text('😒', style: TextStyle(fontSize: 28)),
        ],
      ),
    );
  }
}
