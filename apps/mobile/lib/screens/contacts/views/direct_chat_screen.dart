import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_avatar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  final int conversationId;
  final Map<String, dynamic>? conversation;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final List<PlatformFile> _pendingAttachments = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _hasMore = true;
  String? _error;
  Timer? _pollTimer;
  int _nextPageToLoad = 1;

  Map<String, dynamic> get _otherUser =>
      widget.conversation?['other_user'] as Map<String, dynamic>? ?? const {};

  String get _title {
    final displayName = (_otherUser['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (_otherUser['full_name'] as String? ?? '').trim();
    return fullName.isEmpty ? 'Conversation' : fullName;
  }

  String? get _otherUserAvatar {
    final url = (_otherUser['avatar_url'] as String? ?? '').trim();
    return url.isEmpty ? null : url;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMessages(reset: true);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(reset: false, silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isImageName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.heic');
  }

  String _attachmentSubtitle(Map<String, dynamic> attachment) {
    final sizeBytes = attachment['size_bytes'];
    if (sizeBytes is int && sizeBytes > 0) {
      final kb = sizeBytes / 1024;
      if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
      final mb = kb / 1024;
      return '${mb.toStringAsFixed(1)} MB';
    }
    return (attachment['mime_type'] as String? ?? 'File').toUpperCase();
  }

  IconData _attachmentIconFor(Map<String, dynamic> attachment) {
    final ext = (attachment['extension'] as String? ?? '').toLowerCase();
    final mime = (attachment['mime_type'] as String? ?? '').toLowerCase();
    if (mime.startsWith('image/') ||
        {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}.contains(ext)) {
      return Icons.image_rounded;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (ext == 'doc' || ext == 'docx') return Icons.description_rounded;
    if (ext == 'ppt' || ext == 'pptx') return Icons.slideshow_rounded;
    if (ext == 'zip' || ext == 'rar' || ext == '7z') {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _attachmentColorFor(Map<String, dynamic> attachment) {
    final ext = (attachment['extension'] as String? ?? '').toLowerCase();
    final mime = (attachment['mime_type'] as String? ?? '').toLowerCase();
    if (mime.startsWith('image/') ||
        {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}.contains(ext)) {
      return const Color(0xFF14A44D);
    }
    if (ext == 'pdf') return const Color(0xFFE53935);
    if (ext == 'doc' || ext == 'docx') return const Color(0xFF1E88E5);
    if (ext == 'ppt' || ext == 'pptx') return const Color(0xFFFB8C00);
    return const Color(0xFF757575);
  }

  String _attachmentTypeLabel(Map<String, dynamic> attachment) {
    final ext = (attachment['extension'] as String? ?? '').trim().toUpperCase();
    final mime = (attachment['mime_type'] as String? ?? '').trim();
    if (ext.isNotEmpty) return ext;
    if (mime.startsWith('image/')) return 'IMG';
    return 'FILE';
  }

  bool _isImageAttachment(Map<String, dynamic> attachment) {
    final ext = (attachment['extension'] as String? ?? '').toLowerCase();
    final mime = (attachment['mime_type'] as String? ?? '').toLowerCase();
    return mime.startsWith('image/') ||
        {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}.contains(ext);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels <= 120) {
      _loadOlderMessages();
    }
  }

  List<Map<String, dynamic>> _extractResults(Map<String, dynamic> response) {
    final raw = response['results'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  DateTime? _parseTimestamp(Map<String, dynamic> message) {
    final raw = message['timestamp'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _formatTimestamp(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final now = DateTime.now();
    final sameDay = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;

    if (sameDay) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _messageAuthor(Map<String, dynamic> message) {
    final sender = message['sender'] as Map<String, dynamic>? ?? const {};
    final profile = sender['profile'] as Map<String, dynamic>? ?? const {};
    final senderName = (message['sender_name'] as String? ?? '').trim();
    if (senderName.isNotEmpty) return senderName;
    final displayName = (profile['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (profile['full_name'] as String? ?? '').trim();
    return fullName.isNotEmpty ? fullName : 'Campuz user';
  }

  Future<void> _loadMessages({required bool reset, bool silent = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _messages.clear();
        _hasMore = true;
        _nextPageToLoad = 1;
      });
    }

    final page = reset ? 1 : 1;

    try {
      final response = await AuthApiService.getDirectMessagesPage(
        conversationId: widget.conversationId,
        page: page,
      );
      final results = _extractResults(response).reversed.toList();

      if (!mounted) return;

      setState(() {
        if (reset) {
          _messages
            ..clear()
            ..addAll(results);
          _nextPageToLoad = 2;
        } else {
          final existingIds = _messages.map((m) => m['id']).toSet();
          final fresh = results.where((m) => !existingIds.contains(m['id'])).toList();
          if (fresh.isNotEmpty) {
            _messages.addAll(fresh);
          }
        }
        _hasMore = response['next'] != null;
        _isLoading = false;
        _error = null;
      });

      if (reset || results.isNotEmpty) {
        _scrollToBottom();
      }
    } on AuthApiException catch (error) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _isLoading = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to load messages right now.';
        });
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final response = await AuthApiService.getDirectMessagesPage(
        conversationId: widget.conversationId,
        page: _nextPageToLoad,
      );
      final results = _extractResults(response).reversed.toList();
      final existingIds = _messages.map((m) => m['id']).toSet();
      final older = results.where((m) => !existingIds.contains(m['id'])).toList();

      if (!mounted) return;

      setState(() {
        _messages.insertAll(0, older);
        _hasMore = response['next'] != null;
        if (_hasMore) {
          _nextPageToLoad += 1;
        }
        _isLoadingMore = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load older messages right now.')),
      );
    }
  }

  Future<void> _send() async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _pendingAttachments.isEmpty) return;
    if (_isSending) return;

    setState(() => _isSending = true);
    try {
      final message = await AuthApiService.sendDirectMessage(
        conversationId: widget.conversationId,
        content: content,
        attachments: List<PlatformFile>.from(_pendingAttachments),
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _messages.add(Map<String, dynamic>.from(message));
        _pendingAttachments.clear();
        _isSending = false;
      });
      _scrollToBottom();
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send message right now.')),
      );
    }
  }

  Future<void> _pickAttachments() async {
    if (_isSending) return;
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.any,
    );
    if (result == null || !mounted) return;
    setState(() {
      _pendingAttachments.addAll(
        result.files.where((file) => file.path != null && file.path!.isNotEmpty),
      );
    });
  }

  void _removePendingAttachment(int index) {
    if (index < 0 || index >= _pendingAttachments.length) return;
    setState(() => _pendingAttachments.removeAt(index));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final content = (message['content'] as String? ?? '').trim();
    final isMine = message['is_mine'] as bool? ?? false;
    final timestamp = _formatTimestamp(_parseTimestamp(message));
    final isRead = message['is_read'] as bool? ?? false;
    final attachments = (message['attachments'] as List?) ?? const [];

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primaryDeep : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine ? null : Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              Text(
                _messageAuthor(message),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primaryDeep,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (content.isNotEmpty) ...[
              Text(
                content,
                style: AppTextStyles.body.copyWith(
                  color: isMine ? Colors.white : AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              if (attachments.isNotEmpty) const SizedBox(height: 10),
            ],
            if (attachments.isNotEmpty)
              ...attachments.whereType<Map>().map((raw) {
                final attachment = Map<String, dynamic>.from(raw);
                final url = attachment['url'] as String? ?? '';
                final fileName = (attachment['file_name'] as String? ?? 'Attachment').trim();
                final isImage = _isImageAttachment(attachment);
                final color = _attachmentColorFor(attachment);
                final icon = _attachmentIconFor(attachment);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: url.isNotEmpty
                            ? () async {
                                final uri = Uri.tryParse(url);
                                if (uri != null) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              }
                            : null,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isMine
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isMine
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isImage && url.isNotEmpty)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14),
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1.08,
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(18),
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: color.withValues(alpha: 0.14),
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.all(18),
                                          child: Icon(icon, color: color, size: 34),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  11,
                                  isImage && url.isNotEmpty ? 9 : 11,
                                  11,
                                  10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(icon, color: color, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body.copyWith(
                                              color: isMine ? Colors.white : AppColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            _attachmentSubtitle(attachment),
                                            style: AppTextStyles.caption.copyWith(
                                              color: isMine ? Colors.white70 : AppColors.textSecondary,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (url.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6, top: 1),
                                        child: Icon(
                                          Icons.open_in_new_rounded,
                                          size: 16,
                                          color: isMine ? Colors.white70 : AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -7,
                        right: -7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            _attachmentTypeLabel(attachment),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (content.isNotEmpty || attachments.isNotEmpty) const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timestamp,
                    style: AppTextStyles.caption.copyWith(
                      color: isMine ? Colors.white60 : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 3),
                    Icon(
                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 12,
                      color: isRead
                          ? const Color(0xFF53BDEB)
                          : Colors.white70,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load messages',
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _loadMessages(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 56,
                color: AppColors.primaryDeep,
              ),
              const SizedBox(height: 16),
              Text('Start the conversation', style: AppTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                'Send a message to $_title.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMessages(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        itemCount: _messages.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (_hasMore && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: _isLoadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : TextButton(
                        onPressed: _loadOlderMessages,
                        child: Text(
                          'Load older messages',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
              ),
            );
          }

          final messageIndex = index - (_hasMore ? 1 : 0);
          return _buildMessageBubble(_messages[messageIndex]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surfaceMuted,
              backgroundImage: _otherUserAvatar != null
                  ? NetworkImage(_otherUserAvatar!)
                  : null,
              child: _otherUserAvatar == null
                  ? Text(
                      _title.characters.first.toUpperCase(),
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primaryDeep,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(fontSize: 16),
                  ),
                  Text(
                    'Direct message',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          if (_pendingAttachments.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              color: AppColors.surface,
              child: SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingAttachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final file = _pendingAttachments[index];
                    final isImage = _isImageName(file.name);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 156,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isImage && file.path != null && File(file.path!).existsSync())
                                SizedBox(
                                  height: 78,
                                  child: Image.file(
                                    File(file.path!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _pendingAttachmentTile(file, isImage),
                                  ),
                                )
                              else
                                _pendingAttachmentTile(file, isImage),
                            ],
                          ),
                        ),
                        Positioned(
                          top: -7,
                          left: -7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isImage
                                  ? const Color(0xFF14A44D)
                                  : AppColors.primaryDeep,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isImage ? 'IMG' : 'FILE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => _removePendingAttachment(index),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryDeep,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isSending ? null : _pickAttachments,
                    icon: const Icon(Icons.attach_file_rounded),
                    tooltip: 'Attach file',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(hintText: 'Message'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingAttachmentTile(PlatformFile file, bool isImage) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isImage
                  ? const Color(0xFF14A44D).withValues(alpha: 0.12)
                  : AppColors.primaryDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isImage ? Icons.image_rounded : Icons.attach_file_rounded,
              size: 17,
              color: isImage ? const Color(0xFF14A44D) : AppColors.primaryDeep,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isImage ? 'Image' : 'File',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
