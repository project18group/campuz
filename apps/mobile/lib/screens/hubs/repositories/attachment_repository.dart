import 'dart:async';
import 'package:mobile/screens/hubs/models/attachment.dart';

class AttachmentRepository {
  /// Mocks uploading an attachment.
  /// Reports progress periodically and eventually finishes with success (or fails randomly if we want, but let's stick to success for the happy path placeholder).
  Future<void> uploadAttachment(
    Attachment attachment,
    void Function(UploadState state, double progress) onProgress,
  ) async {
    // Start progress
    onProgress(UploadState.progress, 0.1);
    await Future.delayed(const Duration(milliseconds: 500));
    onProgress(UploadState.progress, 0.4);
    await Future.delayed(const Duration(milliseconds: 500));
    onProgress(UploadState.progress, 0.7);
    await Future.delayed(const Duration(milliseconds: 500));
    onProgress(UploadState.progress, 1.0);
    
    // Simulate slight delay before success
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Hardcoded success for the placeholder
    onProgress(UploadState.success, 1.0);
  }
}
