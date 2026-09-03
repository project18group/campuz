import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class DownloadableImageAttachment extends StatefulWidget {
  final String url;
  final String sizeLabel;
  final VoidCallback onTap;

  const DownloadableImageAttachment({
    super.key,
    required this.url,
    required this.sizeLabel,
    required this.onTap,
  });

  @override
  State<DownloadableImageAttachment> createState() => _DownloadableImageAttachmentState();
}

class _DownloadableImageAttachmentState extends State<DownloadableImageAttachment> {
  bool _isDownloaded = false;

  @override
  Widget build(BuildContext context) {
    if (_isDownloaded) {
      return GestureDetector(
        onTap: widget.onTap,
        child: AspectRatio(
          aspectRatio: 1.08,
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) {
              return Container(
                color: AppColors.primary.withValues(alpha: 0.14),
                alignment: Alignment.center,
                child: Icon(
                  Icons.broken_image_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              );
            },
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isDownloaded = true;
        });
      },
      child: AspectRatio(
        aspectRatio: 1.08,
        child: Container(
          color: AppColors.primary.withValues(alpha: 0.1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A generic blurred/gradient background
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.sizeLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
