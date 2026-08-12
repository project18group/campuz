import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_avatar.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/home/models/hub.dart';

/// Actions available from the long-press bottom sheet on a hub tile.
enum HubAction { togglePin, toggleMute, markAsRead, leave }

/// Shows a modern rounded bottom sheet with actions for [hub].
/// Returns the chosen [HubAction], or null if dismissed.
Future<HubAction?> showHubActionsSheet(BuildContext context, Hub hub) {
  return showModalBottomSheet<HubAction>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // Drag handle.
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          // Hub header.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: hub.avatarColor.withValues(alpha: 0.12),
                  child: Text(
                    hub.initials,
                    style: AppTextStyles.label.copyWith(
                      color: hub.avatarColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hub.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          _sheetTile(
            sheetContext,
            icon: hub.isPinned
                ? Icons.push_pin_outlined
                : Icons.push_pin_rounded,
            label: hub.isPinned ? "Unpin Hub" : "Pin Hub",
            action: HubAction.togglePin,
          ),
          _sheetTile(
            sheetContext,
            icon: hub.isMuted
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: hub.isMuted ? "Unmute Notifications" : "Mute Notifications",
            action: HubAction.toggleMute,
          ),
          _sheetTile(
            sheetContext,
            icon: Icons.mark_chat_read_outlined,
            label: "Mark as Read",
            action: HubAction.markAsRead,
          ),
          _sheetTile(
            sheetContext,
            icon: Icons.logout_rounded,
            label: "Leave Hub",
            action: HubAction.leave,
            destructive: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Widget _sheetTile(
  BuildContext sheetContext, {
  required IconData icon,
  required String label,
  required HubAction action,
  bool destructive = false,
}) {
  final color = destructive ? AppColors.error : AppColors.textPrimary;
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    leading: Icon(icon, color: destructive ? AppColors.error : AppColors.textSecondary),
    title: Text(
      label,
      style: AppTextStyles.label.copyWith(color: color),
    ),
    onTap: () => Navigator.of(sheetContext).pop(action),
  );
}
