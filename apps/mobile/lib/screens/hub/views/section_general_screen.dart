import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/hubs/widget/hub_composer.dart';
import 'package:mobile/shared/widgets/chat_background.dart';
import 'package:url_launcher/url_launcher.dart';

class SectionGeneralScreen extends StatefulWidget {
  final int hubId;
  final Map<String, dynamic> section;
  final Map<String, dynamic>? hub;

  const SectionGeneralScreen({
    super.key,
    required this.hubId,
    required this.section,
    this.hub,
  });

  @override
  State<SectionGeneralScreen> createState() => _SectionGeneralScreenState();
}

class _SectionGeneralScreenState extends State<SectionGeneralScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final List<PlatformFile> _pendingAttachments = [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _sendAsSms = false;
  String? _error;
  int _nextPage = 1;
  Timer? _pollTimer;

  String get _sectionTitle =>
      (widget.section['title'] as String? ?? 'General').trim();

  bool get _canSendAsSms => widget.hub?['can_manage_members'] == true;

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
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels <= 140) {
      _loadOlderMessages();
    }
  }

  String _messageIdKey(Map<String, dynamic> message) => '${message['id'] ?? ''}';

  Future<void> _loadMessages({
    required bool reset,
    bool silent = false,
  }) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _messages.clear();
        _hasMore = true;
        _nextPage = 1;
      });
    }

    try {
      final previousIds = _messages.map(_messageIdKey).toSet();
      final response = await AuthApiService.getHubMessages(
        hubId: widget.hubId,
        page: 1,
      );
      final results = _extractResults(response).reversed.toList();
      final fresh = results
          .where((message) => !previousIds.contains(_messageIdKey(message)))
          .toList();

      if (!mounted) return;

      setState(() {
        if (reset) {
          _messages
            ..clear()
            ..addAll(results);
        } else if (fresh.isNotEmpty) {
          _messages.addAll(fresh);
        }
        _hasMore = response['next'] != null;
        _nextPage = 2;
        _isLoading = false;
        _error = null;
      });

      if (reset || fresh.isNotEmpty) {
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
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final response = await AuthApiService.getHubMessages(
        hubId: widget.hubId,
        page: _nextPage,
      );
      final results = _extractResults(response).reversed.toList();
      final existingIds = _messages.map(_messageIdKey).toSet();
      final older = results
          .where((message) => !existingIds.contains(_messageIdKey(message)))
          .toList();

      if (!mounted) return;

      setState(() {
        _messages.insertAll(0, older);
        _hasMore = response['next'] != null;
        _nextPage += 1;
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
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _pendingAttachments.isEmpty) return;
    if (_isSending) return;

    setState(() => _isSending = true);
    try {
      final message = await AuthApiService.sendHubMessage(
        hubId: widget.hubId,
        content: content,
        sendAsSms: _sendAsSms && _canSendAsSms,
        attachments: List<PlatformFile>.from(_pendingAttachments),
      );

      if (!mounted) return;

      _messageController.clear();
      setState(() {
        final sentMessage = Map<String, dynamic>.from(message);
        final messageKey = _messageIdKey(sentMessage);
        if (!_messages.any((item) => _messageIdKey(item) == messageKey)) {
          _messages.add(sentMessage);
        }
        _pendingAttachments.clear();
        _isSending = false;
        if (_sendAsSms && !_canSendAsSms) {
          _sendAsSms = false;
        }
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
        const SnackBar(content: Text('Unable to send message right now')),
      );
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _displayName(Map<String, dynamic> message) {
    final sender = message['sender'] as Map<String, dynamic>? ?? const {};
    final profile = sender['profile'] as Map<String, dynamic>? ?? const {};
    final senderName = (message['sender_name'] as String? ?? '').trim();
    if (senderName.isNotEmpty) return senderName;
    final displayName = (profile['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (profile['full_name'] as String? ?? '').trim();
    return fullName.isNotEmpty ? fullName : 'Campuz user';
  }

  bool _isImageAttachment(Map<String, dynamic> attachment) {
    final ext = (attachment['extension'] as String? ?? '').toLowerCase();
    final mime = (attachment['mime_type'] as String? ?? '').toLowerCase();
    return mime.startsWith('image/') ||
        {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}.contains(ext);
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

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final url = (attachment['url'] as String? ?? '').trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Future<void> _showEmojiPicker() async {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.42,
          child: EmojiPicker(
            textEditingController: _messageController,
            config: const Config(
              height: 256,
              checkPlatformCompatibility: true,
              skinToneConfig: SkinToneConfig(),
              categoryViewConfig: CategoryViewConfig(),
              bottomActionBarConfig: BottomActionBarConfig(),
              searchViewConfig: SearchViewConfig(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmSendAsSms(bool value) async {
    if (!value) {
      setState(() => _sendAsSms = false);
      return;
    }

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send as SMS?'),
        content: const Text(
          'SMS delivery can use credits and reaches members on their phone numbers. '
          'Only continue for urgent or very important updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _sendAsSms = shouldContinue == true);
  }

  DateTime? _parseTimestamp(Map<String, dynamic> message) {
    final raw = message['timestamp'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _formatTimestamp(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = message['is_mine'] == true;
    final content = (message['content'] as String? ?? '').trim();
    final senderName = isMine ? 'You' : _displayName(message);
    final timestamp = _formatTimestamp(_parseTimestamp(message));
    final attachments = (message['attachments'] as List?) ?? const [];
    final smsSent = message['send_as_sms'] == true ||
        message['sms_delivery_queued'] == true ||
        message['sms_sent'] == true;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
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
            Text(
              senderName,
              style: AppTextStyles.label.copyWith(
                color: isMine ? Colors.white70 : AppColors.primaryDeep,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                content,
                style: AppTextStyles.body.copyWith(
                  color: isMine ? Colors.white : AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ],
            if (attachments.isNotEmpty) ...[
              if (content.isNotEmpty) const SizedBox(height: 10),
              ...attachments.whereType<Map>().map((raw) {
                final attachment = Map<String, dynamic>.from(raw);
                final url = (attachment['url'] as String? ?? '').trim();
                final fileName =
                    (attachment['file_name'] as String? ?? 'Attachment').trim();
                final isImage = _isImageAttachment(attachment);
                final color = _attachmentColorFor(attachment);
                final icon = _attachmentIconFor(attachment);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: url.isNotEmpty ? () => _openAttachment(attachment) : null,
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
                                          color: isMine
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        _attachmentSubtitle(attachment),
                                        style: AppTextStyles.caption.copyWith(
                                          color: isMine
                                              ? Colors.white70
                                              : AppColors.textSecondary,
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
                );
              }),
            ],
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
                    ),
                  ),
                  if (smsSent) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.sms_rounded,
                      size: 13,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sent as SMS',
                      style: AppTextStyles.caption.copyWith(
                        color: isMine ? Colors.white60 : AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
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
              Icon(
                Icons.cloud_off_outlined,
                size: 52,
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
                child: const Text('Try again'),
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
              Icon(
                Icons.forum_outlined,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 16),
              Text(
                'No messages yet',
                style: AppTextStyles.heading.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to start the discussion.',
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

    final itemCount = _messages.length + (_hasMore ? 1 : 0);
    return RefreshIndicator(
      onRefresh: () => _loadMessages(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        itemCount: itemCount,
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

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: HubComposer(
          showSendAsSms: _canSendAsSms,
          sendAsSms: _sendAsSms,
          canSend: !_isSending,
          controller: _messageController,
          attachments: _pendingAttachments,
          onSmsChanged: _confirmSendAsSms,
          onAttach: _pickAttachments,
          onEmoji: _showEmojiPicker,
          onRemoveAttachment: _removePendingAttachment,
          onSend: _sendMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (_sectionTitle.isNotEmpty ? _sectionTitle : 'General').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTextStyles.label),
            Text(
              'General discussion',
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _loadMessages(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: ChatBackground(child: _buildMessages())),
          _buildComposer(),
        ],
      ),
    );
  }
}