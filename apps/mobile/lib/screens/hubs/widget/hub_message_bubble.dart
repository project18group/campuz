import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/hubs/models/hub_message.dart';

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

        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,

            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 10),

                padding: const EdgeInsets.all(12),

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // sender
                    // message
                    // time

                    // Sender
                    Text(
                      message.sender,
                      style: AppTextStyles.label.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Message
                    Text(
                      message.message!,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Time + SMS
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
                              Icons.sms,
                              size: 14,
                              color: Colors.white60,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,

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
    );
  }
}
