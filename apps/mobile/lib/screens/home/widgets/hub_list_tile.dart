import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/home/models/hub.dart';

/// Sprint 9 — WhatsApp-style chat list tile for a joined hub.
class HubListTile extends StatelessWidget {
  final Hub hub;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const HubListTile({
    super.key,
    required this.hub,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = hub.hasUnread;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar — colored circle with initials.
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  hub.name.isNotEmpty ? hub.name[0].toUpperCase() : '?',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + latest message preview.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hub.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (hub.isMuted) ...[
                        Icon(
                          Icons.volume_off_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          hub.latestMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right column — timestamp, then unread badge / pin.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hub.timestamp,
                  style: AppTextStyles.caption.copyWith(
                    color: hasUnread
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hub.isPinned)
                      Padding(
                        padding: EdgeInsets.only(right: hasUnread ? 6 : 0),
                        child: Transform.rotate(
                          angle: 0.6,
                          child: Icon(
                            Icons.push_pin,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    if (hasUnread)
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          hub.unreadCount > 99 ? "99+" : "${hub.unreadCount}",
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (!hasUnread && !hub.isPinned) const SizedBox(height: 22),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}