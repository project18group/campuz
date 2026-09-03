import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:mobile/core/theme/app_colors.dart';

class ImageCropperUtils {
  static Future<List<PlatformFile>> cropImages(List<PlatformFile> originalFiles) async {
    final List<PlatformFile> croppedFiles = [];
    
    for (var file in originalFiles) {
      if (file.path == null) {
        croppedFiles.add(file);
        continue;
      }
      
      final ext = file.path!.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
      
      if (!isImage) {
        croppedFiles.add(file);
        continue;
      }
      
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path!,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Image',
            toolbarColor: AppColors.primaryDeep,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Edit Image',
          ),
        ],
      );
      
      if (croppedFile != null) {
        final size = await File(croppedFile.path).length();
        croppedFiles.add(PlatformFile(
          path: croppedFile.path,
          name: croppedFile.path.split('/').last,
          size: size,
        ));
      } else {
        // If crop is cancelled, we drop it (assume user cancelled this image)
      }
    }
    
    return croppedFiles;
  }
}
