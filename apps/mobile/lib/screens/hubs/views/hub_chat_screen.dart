import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/hubs/widget/hub_composer.dart';

class HubChatScreen extends StatefulWidget {
  const HubChatScreen({super.key, this.hub, this.hubId});

  final Map<String, dynamic>? hub;
  final int? hubId;

  @override
  State<HubChatScreen> createState() => _HubChatScreenState();
}

class _HubChatScreenState extends State<HubChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _sendAsSms = false;
  String? _error;
  int _nextPage = 1;
  Timer? _pollTimer;

  int get _hubId {
    final value = widget.hub?['id'] ?? widget.hubId;
    return value is int ? value : int.tryParse('$value') ?? 0;
  }

  String get _hubName =>
      (widget.hub?['name'] as String? ?? 'Hub').trim().isEmpty
          ? 'Hub'
          : (widget.hub?['name'] as String? ?? 'Hub').trim();

  int get _memberCount {
    final value = widget.hub?['members_count'];
    return value is int ? value : 0;
  }

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

  Future<void> _loadMessages({
    required bool reset,
    bool silent = false,
  }) async {
    if (_hubId == 0) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No hub selected.';
      });
      return;
    }

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
      final previousIds = _messages.map((message) => message['id']).toSet();
      final response = await AuthApiService.getHubMessages(
        hubId: _hubId,
        page: 1,
      );
      final results = _extractResults(response).reversed.toList();
      final fresh = results
          .where((message) => !previousIds.contains(message['id']))
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
          _error = 'Unable to load hub messages right now.';
        });
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoading || _isLoadingMore || !_hasMore || _hubId == 0) return;

    setState(() => _isLoadingMore = true);
    try {
      final response = await AuthApiService.getHubMessages(
        hubId: _hubId,
        page: _nextPage,
      );
      final results = _extractResults(response).reversed.toList();
      final existingIds = _messages.map((message) => message['id']).toSet();
      final older = results
          .where((message) => !existingIds.contains(message['id']))
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
    if (content.isEmpty || _isSending || _hubId == 0) return;

    setState(() => _isSending = true);
    try {
      final message = await AuthApiService.sendHubMessage(
        hubId: _hubId,
        content: content,
        sendAsSms: _sendAsSms && _canSendAsSms,
      );

      if (!mounted) return;

      _messageController.clear();
      setState(() {
        _messages.add(Map<String, dynamic>.from(message));
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

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
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
            const SizedBox(height: 6),
            Text(
              content,
              style: AppTextStyles.body.copyWith(
                color: isMine ? Colors.white : AppColors.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                timestamp,
                style: AppTextStyles.caption.copyWith(
                  color: isMine ? Colors.white60 : AppColors.textSecondary,
                ),
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
                size: 52,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load hub messages',
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
                'Start the discussion for $_hubName.',
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
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: HubComposer(
          showSendAsSms: _canSendAsSms,
          sendAsSms: _sendAsSms,
          controller: _messageController,
          onSmsChanged: (value) {
            setState(() {
              _sendAsSms = value;
            });
          },
          onAttach: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attachments are coming soon.')),
            );
          },
          onSend: _isSending ? () {} : _sendMessage,
        ),
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
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            AppAvatar(avatarUrl: '', fallbackName: _hubName, size: 40),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _hubName,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(fontSize: 16),
                  ),
                  Text(
                    '$_memberCount members',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _loadMessages(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () {
              context.push(
                '/hub-info',
                extra: widget.hub ??
                    {
                      'id': _hubId,
                      'name': _hubName,
                      'members_count': _memberCount,
                    },
              );
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildComposer(),
        ],
      ),
    );
  }
}
