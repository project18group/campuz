enum UploadState {
  placeholder,
  progress,
  success,
  failed,
}

class Attachment {
  final String id;
  final String name;
  final String type;
  final int size; // in bytes
  final String? path;
  final String? url;
  UploadState uploadState;
  double uploadProgress; // 0.0 to 1.0

  Attachment({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    this.path,
    this.url,
    this.uploadState = UploadState.placeholder,
    this.uploadProgress = 0.0,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
