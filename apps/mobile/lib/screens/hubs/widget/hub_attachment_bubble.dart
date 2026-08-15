import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/hubs/models/hub_message.dart';
import 'package:open_file/open_file.dart';

class HubAttachmentBubble extends StatelessWidget {
  final HubMessage message;
  final VoidCallback onLongPress;

  const HubAttachmentBubble({
    super.key,
    required this.message,
    required this.onLongPress,
  });

  Color _colorForType() {
    final type = message.attachmentType?.toLowerCase() ?? '';
    if (type == 'pdf') return Colors.redAccent;
    if (type == 'docx' || type == 'doc') return Colors.blueAccent;
    if (type == 'pptx' || type == 'ppt') return Colors.orangeAccent;
    if (type == 'image' || type == 'jpg' || type == 'png') {
      return Colors.greenAccent;
    }
    return Colors.grey;
  }

  IconData _iconForType() {
    final type = message.attachmentType?.toLowerCase() ?? '';
    if (type == 'pdf') return Icons.picture_as_pdf;
    if (type == 'docx' || type == 'doc') return Icons.description;
    if (type == 'pptx' || type == 'ppt') return Icons.slideshow;
    if (type == 'image' || type == 'jpg' || type == 'png') return Icons.image;
    return Icons.insert_drive_file;
  }

  void _openFile(BuildContext context) {
    if (message.attachmentPath != null) {
      final file = File(message.attachmentPath!);
      if (file.existsSync()) {
        OpenFile.open(message.attachmentPath);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File no longer exists locally')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No local path available for this file')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage =
        message.attachmentType == 'image' ||
        message.attachmentType == 'jpg' ||
        message.attachmentType == 'png';
    final hasLocalImage =
        isImage &&
        message.attachmentPath != null &&
        File(message.attachmentPath!).existsSync();

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: () => _openFile(context),
        child: UnconstrainedBox(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.only(
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          key: const Key('sender_name_key'),
                          child: Text(
                            message.sender,
                            style: AppTextStyles.label.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.12),
                            child: hasLocalImage
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Image.file(
                                        File(message.attachmentPath!),
                                        fit: BoxFit.cover,
                                        width: 220,
                                        height: 220,
                                      ),
                                      Container(
                                        width: 220,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        color: Colors.black26,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.image,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                message.attachmentName ??
                                                    'Image',
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _colorForType().withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            _iconForType(),
                                            color: _colorForType(),
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                message.attachmentName ??
                                                    'Attachment',
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                message.attachmentType
                                                        ?.toUpperCase() ??
                                                    'FILE',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      color: Colors.white54,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.open_in_new,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        if (message.message != null &&
                            message.message!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              message.message!,
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
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
                      margin: const EdgeInsets.only(
                        top: -4,
                        bottom: 8,
                        right: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        message.reaction!,
                        style: const TextStyle(fontSize: 16),
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