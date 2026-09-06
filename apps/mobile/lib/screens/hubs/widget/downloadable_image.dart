import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/theme/app_colors.dart';

class DownloadableImageAttachment extends StatelessWidget {
  final String url;
  final String? localPath;
  final String sizeLabel;
  final VoidCallback onTap;

  const DownloadableImageAttachment({
    super.key,
    required this.url,
    this.localPath,
    required this.sizeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Instant local preview if the file exists on the sender's device
    if (localPath != null && localPath!.trim().isNotEmpty) {
      final localFile = File(localPath!);
      if (localFile.existsSync()) {
        return GestureDetector(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 1.08,
            child: Image.file(
              localFile,
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    // 2. Direct network image rendering with CachedNetworkImage
    String effectiveUrl = url.trim();
    if (effectiveUrl.contains('/raw/upload/')) {
      effectiveUrl = effectiveUrl.replaceAll('/raw/upload/', '/image/upload/');
    }

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.08,
        child: effectiveUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: effectiveUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  return Container(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sizeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            : Container(
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Center(
                  child: Icon(Icons.image_rounded, color: AppColors.primary, size: 32),
                ),
              ),
      ),
    );
  }
}
