import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String url;
  final String fileName;
  final String? title;

  const DocumentViewerScreen({
    super.key,
    required this.url,
    required this.fileName,
    this.title,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _localFilePath;
  String? _errorMessage;
  int _fileSizeBytes = 0;

  WebViewController? _webViewController;
  bool _isWebViewSupported = false;

  String get _extension {
    final ext = p.extension(widget.fileName).toLowerCase().replaceAll('.', '');
    if (ext.isNotEmpty) return ext;
    final uriExt = p.extension(Uri.tryParse(widget.url)?.path ?? '').toLowerCase().replaceAll('.', '');
    return uriExt.isNotEmpty ? uriExt : 'doc';
  }

  Color get _badgeColor {
    switch (_extension) {
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
        return Colors.blueAccent;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orangeAccent;
      case 'txt':
        return Colors.blueGrey;
      default:
        return AppColors.primary;
    }
  }

  IconData get _badgeIcon {
    switch (_extension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _initViewer();
  }

  Future<void> _initViewer() async {
    // For PDFs, DOCs, PPTs, Google Docs Viewer can render directly inside WebView
    final supportedPreviewTypes = {'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'};
    if (supportedPreviewTypes.contains(_extension)) {
      _isWebViewSupported = true;
      final encodedUrl = Uri.encodeComponent(widget.url);
      final previewUrl = 'https://docs.google.com/gview?embedded=true&url=$encodedUrl';

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _isLoading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (error) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(previewUrl));
    } else {
      _isLoading = false;
    }

    // Also download/cache the file locally in the background for native open/save
    _downloadFile();
  }

  Future<void> _downloadFile() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = widget.fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final localFile = File(p.join(tempDir.path, sanitizedName));

      if (await localFile.exists() && await localFile.length() > 0) {
        final length = await localFile.length();
        if (mounted) {
          setState(() {
            _localFilePath = localFile.path;
            _fileSizeBytes = length;
            _isDownloading = false;
            _downloadProgress = 1.0;
          });
        }
        return;
      }

      final uri = Uri.parse(widget.url);
      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final contentLength = response.contentLength ?? 0;
        int receivedBytes = 0;
        final sink = localFile.openWrite();

        await response.stream.listen(
          (chunk) {
            receivedBytes += chunk.length;
            sink.add(chunk);
            if (contentLength > 0 && mounted) {
              setState(() {
                _downloadProgress = receivedBytes / contentLength;
              });
            }
          },
          cancelOnError: true,
        ).asFuture();

        await sink.close();

        if (mounted) {
          setState(() {
            _localFilePath = localFile.path;
            _fileSizeBytes = receivedBytes;
            _isDownloading = false;
            _downloadProgress = 1.0;
          });
        }
      } else {
        throw Exception('Server responded with status code ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Failed to download document: $e';
        });
      }
    }
  }

  Future<void> _openWithNativeApp() async {
    if (_localFilePath == null) {
      await _downloadFile();
      if (_localFilePath == null) return;
    }

    final result = await OpenFile.open(_localFilePath!);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: ${result.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _saveToDevice() async {
    if (_localFilePath == null) {
      await _downloadFile();
      if (_localFilePath == null) return;
    }

    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      targetDir ??= await getApplicationDocumentsDirectory();

      final sanitizedName = widget.fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final destinationPath = p.join(targetDir.path, sanitizedName);
      final sourceFile = File(_localFilePath!);
      await sourceFile.copy(destinationPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Saved to ${p.basename(destinationPath)}')),
              ],
            ),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(destinationPath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _shareDocument() async {
    if (_localFilePath == null) {
      await _downloadFile();
      if (_localFilePath == null) return;
    }

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(_localFilePath!)],
      text: widget.fileName,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? widget.fileName,
              style: AppTextStyles.title.copyWith(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.title != null)
              Text(
                widget.fileName,
                style: AppTextStyles.caption.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareDocument,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Save to device',
            onPressed: _saveToDevice,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Open with app',
            onPressed: _openWithNativeApp,
          ),
        ],
      ),
      body: Column(
        children: [
          // File Meta Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _badgeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_badgeIcon, color: _badgeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _extension.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _badgeColor,
                            ),
                          ),
                          if (_fileSizeBytes > 0) ...[
                            const SizedBox(width: 6),
                            Text('•', style: AppTextStyles.caption),
                            const SizedBox(width: 6),
                            Text(
                              _formatBytes(_fileSizeBytes),
                              style: AppTextStyles.caption,
                            ),
                          ],
                          if (_isDownloading) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Downloading ${(_downloadProgress * 100).toInt()}%',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openWithNativeApp,
                  icon: const Icon(Icons.launch_rounded, size: 16),
                  label: const Text('Open'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: AppTextStyles.label.copyWith(fontSize: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isDownloading && _downloadProgress < 1.0)
            LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 3,
            ),

          // Main View Area
          Expanded(
            child: _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _downloadFile,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry Download'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _isWebViewSupported && _webViewController != null
                    ? Stack(
                        children: [
                          WebViewWidget(controller: _webViewController!),
                          if (_isLoading)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Rendering document preview...',
                                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: _badgeColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_badgeIcon, color: _badgeColor, size: 40),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                widget.fileName,
                                style: AppTextStyles.title.copyWith(fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This file type can be opened in external office apps installed on your phone.',
                                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _saveToDevice,
                                    icon: const Icon(Icons.download_rounded),
                                    label: const Text('Save File'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: BorderSide(color: AppColors.primary),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _openWithNativeApp,
                                    icon: const Icon(Icons.open_in_new_rounded),
                                    label: const Text('Open App'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
