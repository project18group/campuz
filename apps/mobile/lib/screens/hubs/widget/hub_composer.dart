import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class HubComposer extends StatelessWidget {
  final bool showSendAsSms;
  final bool sendAsSms;
  final bool canSend;
  final TextEditingController controller;
  final List<PlatformFile> attachments;
  final ValueChanged<bool> onSmsChanged;
  final VoidCallback onAttach;
  final VoidCallback? onEmoji;
  final VoidCallback onSend;
  final ValueChanged<int>? onRemoveAttachment;

  const HubComposer({
    super.key,
    this.showSendAsSms = false,
    required this.sendAsSms,
    this.canSend = true,
    required this.controller,
    this.attachments = const [],
    required this.onSmsChanged,
    required this.onAttach,
    this.onEmoji,
    required this.onSend,
    this.onRemoveAttachment,
  });

  Widget _buildAttachmentChip(PlatformFile file, int index) {
    final name = file.name.trim().isEmpty ? 'Attachment' : file.name.trim();
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insert_drive_file_outlined, size: 16),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRemoveAttachment != null) ...[
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              onPressed: () => onRemoveAttachment!(index),
              icon: const Icon(Icons.close, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSendAsSms)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Send as SMS',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Urgent only',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "SMS reaches members' phone numbers and may use credits.",
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                Switch(value: sendAsSms, onChanged: onSmsChanged),
              ],
            ),
          if (showSendAsSms) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Text(
                'Only send as SMS for urgent or very important info. SMS goes to members\' phone numbers and may use credits.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                children: List.generate(
                  attachments.length,
                  (index) => _buildAttachmentChip(attachments[index], index),
                ),
              ),
            ),
          ],

          Row(
            children: [
              IconButton(
                onPressed: onAttach,
                icon: const Icon(Icons.attach_file),
              ),
              if (onEmoji != null)
                IconButton(
                  onPressed: onEmoji,
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),

              Expanded(
                child: TextField(
                  controller: controller,

                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),

                  keyboardType: TextInputType.multiline,

                  maxLines: null,
                  minLines: 1,

                  decoration: InputDecoration(
                    hintText: "Type a message",

                    hintStyle: AppTextStyles.label,

                    filled: true,

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),

                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              IconButton(
                onPressed: canSend ? onSend : null,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
