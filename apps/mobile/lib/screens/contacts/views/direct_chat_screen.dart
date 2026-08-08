import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

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
  List<Map<String, dynamic>> _messages = const [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  Timer? _pollTimer;

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
    _loadMessages();
    // Poll for new messages every 5 seconds while the screen is open.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final messages = await AuthApiService.getDirectMessages(
        conversationId: widget.conversationId,
      );
      if (mounted) {
        final prevCount = _messages.length;
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        // Auto-scroll on first load or whenever new messages arrive.
        if (prevCount == 0 || messages.length > prevCount) {
          _scrollToBottom();
        }
      }
    } on AuthApiException catch (error) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _send() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final message = await AuthApiService.sendDirectMessage(
        conversationId: widget.conversationId,
        content: content,
      );
      if (mounted) {
        _messageController.clear();
        setState(() {
          _messages = [..._messages, message];
          _isSending = false;
        });
        _scrollToBottom();
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadMessages,
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final content = (message['content'] as String? ?? '').trim();
        final isMine = message['is_mine'] as bool? ?? false;

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isMine ? AppColors.primaryDeep : AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: isMine ? null : Border.all(color: AppColors.border),
            ),
            child: Text(
              content,
              style: AppTextStyles.body.copyWith(
                color: isMine ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}
