import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class HubComposer extends StatelessWidget {
  final bool showSendAsSms;
  final bool sendAsSms;
  final bool isSending;
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
    this.isSending = false,
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
    final sizeLabel = file.size > 0
        ? (file.size >= 1024 * 1024
            ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
            : '${(file.size / 1024).toStringAsFixed(0)} KB')
        : 'Size unknown';
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
            constraints: const BoxConstraints(maxWidth: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sizeLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
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

  Widget _buildSmsNotice() {
    if (!showSendAsSms) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Switch(
            value: sendAsSms,
            onChanged: attachments.isEmpty ? onSmsChanged : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              attachments.isEmpty
                  ? 'Only use SMS for urgent or very important text updates.'
                  : 'SMS works only for text-only updates.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
          if (showSendAsSms) _buildSmsNotice(),
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

              isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
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
