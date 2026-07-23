import 'dart:async';

import 'package:mobile/screens/hubs/models/attachment.dart';

/// Download lifecycle for a received attachment.
///
/// Kept separate from [UploadState] so the existing upload UI continues to
/// work untouched — download state is additive.
enum DownloadState {
  none,
  downloading,
  completed,
  failed,
}

typedef DownloadProgressCallback = void Function(
  DownloadState state,
  double progress,
);

/// PLACEHOLDER download service — no backend yet.
///
/// Mirrors the simulation style of `AttachmentRepository.uploadAttachment`:
/// progress is reported through a callback in timed steps using
/// [Future.delayed].
class FileDownloadService {
  FileDownloadService._();

  /// Shared instance so download state survives bubble rebuilds and
  /// list-view recycling.
  static final FileDownloadService instance = FileDownloadService._();

  final Map<String, DownloadState> _states = {};
  final Map<String, double> _progress = {};
  final Set<String> _cancelRequests = {};

  int _attempts = 0;

  /// Force the next [downloadAttachment] call to fail — handy for testing the
  /// Failed → retry flow. Resets automatically after one use.
  bool forceNextFailure = false;

  /// Current download state for an attachment (defaults to [DownloadState.none]).
  DownloadState stateFor(String attachmentId) =>
      _states[attachmentId] ?? DownloadState.none;

  /// Current download progress (0.0 – 1.0) for an attachment.
  double progressFor(String attachmentId) => _progress[attachmentId] ?? 0.0;

  /// Whether the attachment has finished downloading.
  bool isDownloaded(String attachmentId) =>
      stateFor(attachmentId) == DownloadState.completed;

  /// Mocks downloading an attachment.
  ///
  /// Reports progress periodically via [onProgress] and eventually finishes
  /// with [DownloadState.completed]. Roughly 1 in 5 attempts fails
  /// (deterministic: every 5th call), so the Failed state is reachable while
  /// the default flow succeeds.
  Future<void> downloadAttachment(
    Attachment attachment,
    DownloadProgressCallback onProgress,
  ) async {
    final id = attachment.id;
    if (stateFor(id) == DownloadState.downloading) return;

    _cancelRequests.remove(id);
    _attempts++;
    final shouldFail = forceNextFailure || _attempts % 5 == 0;
    forceNextFailure = false;

    void report(DownloadState state, double progress) {
      _states[id] = state;
      _progress[id] = progress;
      onProgress(state, progress);
    }

    // Start progress
    report(DownloadState.downloading, 0.05);

    const steps = [0.2, 0.45, 0.7, 0.9];
    for (final step in steps) {
      await Future.delayed(const Duration(milliseconds: 450));
      if (_cancelRequests.remove(id)) {
        report(DownloadState.none, 0.0);
        return;
      }
      if (shouldFail && step > 0.5) {
        // Simulated mid-download failure.
        report(DownloadState.failed, step);
        return;
      }
      report(DownloadState.downloading, step);
    }

    // Simulate slight delay before completion
    await Future.delayed(const Duration(milliseconds: 300));
    if (_cancelRequests.remove(id)) {
      report(DownloadState.none, 0.0);
      return;
    }
    report(DownloadState.completed, 1.0);
  }

  /// Requests cancellation of an in-flight download. Takes effect at the next
  /// simulated progress step; the attachment returns to [DownloadState.none].
  void cancelDownload(String attachmentId) {
    if (stateFor(attachmentId) == DownloadState.downloading) {
      _cancelRequests.add(attachmentId);
    }
  }

  /// Clears tracked state for an attachment (e.g. after its message is deleted).
  void reset(String attachmentId) {
    _states.remove(attachmentId);
    _progress.remove(attachmentId);
    _cancelRequests.remove(attachmentId);
  }
}
