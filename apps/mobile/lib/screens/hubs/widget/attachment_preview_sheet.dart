import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class AttachmentPreviewSheet extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String fileType; // pdf, image, doc, ppt, etc.

  const AttachmentPreviewSheet({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.fileType,
  });

  @override
  State<AttachmentPreviewSheet> createState() => _AttachmentPreviewSheetState();
}

class _AttachmentPreviewSheetState extends State<AttachmentPreviewSheet> {
  final _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Color _colorForType() {
    final type = widget.fileType.toLowerCase();
    if (type == 'pdf') return Colors.redAccent;
    if (type == 'docx' || type == 'doc') return Colors.blueAccent;
    if (type == 'pptx' || type == 'ppt') return Colors.orangeAccent;
    if (type == 'image' || type == 'jpg' || type == 'png') {
      return Colors.greenAccent;
    }
    return Colors.grey;
  }

  IconData _iconForType() {
    final type = widget.fileType.toLowerCase();
    if (type == 'pdf') return Icons.picture_as_pdf;
    if (type == 'docx' || type == 'doc') return Icons.description;
    if (type == 'pptx' || type == 'ppt') return Icons.slideshow;
    if (type == 'image' || type == 'jpg' || type == 'png') return Icons.image;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    final isImage =
        widget.fileType == 'image' ||
        widget.fileType == 'jpg' ||
        widget.fileType == 'png';
    final showImagePreview = isImage && File(widget.filePath).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Preview Attachment",
                style: AppTextStyles.title.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, null),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preview Card
          Container(
            width: double.infinity,
            height: showImagePreview ? 220 : 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: showImagePreview
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(widget.filePath), fit: BoxFit.cover),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _colorForType().withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForType(),
                            color: _colorForType(),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            widget.fileName,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.fileType.toUpperCase(),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          // Caption Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _captionController,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: "Add a caption...",
                    hintStyle: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context, _captionController.text);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}