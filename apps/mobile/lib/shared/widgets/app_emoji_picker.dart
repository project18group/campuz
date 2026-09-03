import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class AppEmojiPicker extends StatelessWidget {
  final TextEditingController? textEditingController;
  final VoidCallback? onClose;
  final void Function(Category?, Emoji)? onEmojiSelected;

  const AppEmojiPicker({
    super.key,
    this.textEditingController,
    this.onClose,
    this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Pick an emoji',
                  style: AppTextStyles.title.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceMuted,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: EmojiPicker(
              textEditingController: textEditingController,
              onEmojiSelected: onEmojiSelected,
              config: Config(
                height: 256,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: AppColors.surface,
                  buttonMode: ButtonMode.MATERIAL,
                  columns: 7,
                  emojiSizeMax: 28,
                ),
                skinToneConfig: SkinToneConfig(
                  dialogBackgroundColor: AppColors.surface,
                  indicatorColor: AppColors.textSecondary,
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: AppColors.surface,
                  iconColorSelected: AppColors.primary,
                  indicatorColor: AppColors.primary,
                  iconColor: AppColors.textSecondary,
                  dividerColor: Colors.transparent,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: AppColors.surface,
                  buttonIconColor: AppColors.textSecondary,
                  buttonColor: AppColors.surface,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: AppColors.surface,
                  buttonIconColor: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
