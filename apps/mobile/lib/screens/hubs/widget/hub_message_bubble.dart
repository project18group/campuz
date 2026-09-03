import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/hubs/models/hub_message.dart';
import 'package:mobile/shared/widgets/linkified_text.dart';

class HubMessageBubble extends StatelessWidget {
  final HubMessage message;
  final VoidCallback onLongPress;

  const HubMessageBubble({
    super.key,
    required this.message,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: UnconstrainedBox(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.sender,
                          style: AppTextStyles.label.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LinkifiedText(
                          text: message.message ?? '',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          linkStyle: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message.time,
                                style: AppTextStyles.body.copyWith(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                              if (message.smsSent) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.sms_rounded,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'SMS',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (message.reaction != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message.reaction!,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
