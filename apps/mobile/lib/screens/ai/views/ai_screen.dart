import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/chat_background.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/services/campus_ai_engine.dart';

class AiChatMessage {
  final String sender; // 'user' | 'ai'
  final String text;
  final DateTime timestamp;
  final String? intent;
  final Map<String, dynamic>? metadata;

  AiChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.intent,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        if (intent != null) 'intent': intent,
        if (metadata != null) 'metadata': metadata,
      };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) => AiChatMessage(
        sender: json['sender'] as String? ?? 'user',
        text: json['text'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        intent: json['intent'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen>
    with AutomaticKeepAliveClientMixin {
  static const _historyKey = 'campuz_ai_chat_history_v2';

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<AiChatMessage> _messages = [];
  bool _isTyping = false;
  String _userName = 'Student';

  @override
  bool get wantKeepAlive => true;

  static const List<Map<String, String>> _quickActions = [
    {
      'label': '📅 Extract Deadlines',
      'prompt':
          'Extract deadline from: Submit Assignment 2 on Portal by next Friday at 5:00 PM.',
    },
    {
      'label': '📝 Summarize Notes',
      'prompt':
          'Summarize this: The database lecture covered normalization up to 3NF, BCNF anomalies, and transaction ACID properties for concurrency control.',
    },
    {
      'label': '⏰ Create Study Plan',
      'prompt':
          'Create a study plan for Software Engineering and Data Structures.',
    },
    {
      'label': '💡 Exam Prep Tips',
      'prompt': 'Give me the top exam preparation techniques for finals.',
    },
    {
      'label': '📚 Assignment Help',
      'prompt':
          'Help me structure an academic outline and citation checklist for my research paper.',
    },
    {
      'label': '👥 Hub Features',
      'prompt':
          'How do Hub Sections, Resources, and Broadcasts work in Campuz?',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final cached = await AuthApiService.readCachedCurrentUser();
    if (cached != null && mounted) {
      final profile = cached['profile'] as Map<String, dynamic>?;
      final fullName = profile?['full_name'] as String?;
      final displayName = profile?['display_name'] as String?;
      final resolvedName = (displayName?.trim().isNotEmpty == true
              ? displayName
              : fullName?.trim()) ??
          'Student';
      setState(() {
        _userName = resolvedName.isNotEmpty ? resolvedName : 'Student';
      });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List && mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(
              list
                  .whereType<Map<String, dynamic>>()
                  .map((e) => AiChatMessage.fromJson(e)),
            );
          });
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(
        _messages.take(60).map((m) => m.toJson()).toList(),
      );
      await prefs.setString(_historyKey, serialized);
    } catch (_) {}
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'Are you sure you want to clear your conversation with the AI Assistant?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _messages.clear());
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _messageController.text).trim();
    if (text.isEmpty || _isTyping) return;

    _messageController.clear();
    setState(() {
      _messages.add(
        AiChatMessage(
          sender: 'user',
          text: text,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    _saveHistory();
    _scrollToBottom();

    Map<String, dynamic>? response;

    // 1. Attempt Backend AI Chat Endpoint with a 10-second timeout
    try {
      final priorHistory = _messages
          .take(_messages.length - 1)
          .map((m) => {'sender': m.sender, 'text': m.text})
          .toList();

      response = await AuthApiService.sendAiChatMessage(
        message: text,
        history: priorHistory,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Backend is asleep, slow, or offline -> fallback seamlessly to in-app engine
      response = null;
    }

    // 2. In-App Academic AI Engine Fallback (guarantees 100% uptime and instant answers)
    final finalResponse = response ??
        CampusAiEngine.generateResponse(
          userMessage: text,
          studentName: _userName,
        );

    final reply = finalResponse['reply'] as String? ??
        "I have processed your request. Let me know if you need further academic assistance!";
    final intent = finalResponse['intent'] as String?;
    final metadata = finalResponse['metadata'] as Map<String, dynamic>?;

    if (mounted) {
      setState(() {
        _messages.add(
          AiChatMessage(
            sender: 'ai',
            text: reply,
            timestamp: DateTime.now(),
            intent: intent,
            metadata: metadata,
          ),
        );
        _isTyping = false;
      });
      _saveHistory();
      _scrollToBottom();
    }
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _syncToCalendar(Map<String, dynamic> metadata) async {
    final deadlineIso = metadata['deadline_iso'] as String?;
    if (deadlineIso == null) return;

    final date = DateTime.tryParse(deadlineIso);
    if (date == null) return;

    final taskTitle =
        metadata['task_title'] as String? ?? 'Academic Submission';
    final courseName = metadata['course_name'] as String? ?? 'Coursework';

    final event = Event(
      title: '$taskTitle ($courseName)',
      description: 'Extracted by Campuz Academic AI Assistant.\nDue: ${metadata['formatted_date'] ?? date.toString()}',
      location: 'Campuz App',
      startDate: date,
      endDate: date.add(const Duration(hours: 1)),
    );

    try {
      await Add2Calendar.addEvent2Cal(event);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synced to device calendar!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open device calendar.')),
        );
      }
    }
  }

  Widget _buildWelcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 58,
                  color: AppColors.primaryForeground,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Campuz Academic AI",
                style: AppTextStyles.heading.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryForeground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Hello, $_userName! 👋\n\nI am your intelligent academic companion. I extract deadlines, summarize readings, create study timetables, and assist with your coursework.",
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Quick Actions & Capabilities:",
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: _quickActions.map((action) {
                  return ActionChip(
                    backgroundColor: AppColors.surfaceMuted,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    label: Text(
                      action['label']!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _sendMessage(action['prompt']),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg) {
    final isUser = msg.sender == 'user';
    final text = msg.text;
    final metadata = msg.metadata;
    final hasDeadline = metadata != null && metadata['deadline_found'] == true;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primaryDeep : AppColors.surface,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight:
                isUser ? const Radius.circular(4) : const Radius.circular(18),
            bottomLeft:
                isUser ? const Radius.circular(18) : const Radius.circular(4),
          ),
          border: isUser ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: AppColors.primaryForeground,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "Campuz AI",
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryForeground,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: "Copy response",
                    color: AppColors.textSecondary,
                    onPressed: () => _copyMessage(text),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (isUser)
              Text(
                text,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  height: 1.4,
                ),
              )
            else
              MarkdownBody(
                data: text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                  h1: AppTextStyles.title.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryForeground,
                  ),
                  h2: AppTextStyles.title.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryForeground,
                    fontSize: 18,
                  ),
                  h3: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryForeground,
                    fontSize: 15,
                  ),
                  strong: const TextStyle(fontWeight: FontWeight.w700),
                  listBullet: AppTextStyles.body.copyWith(
                    color: AppColors.primaryForeground,
                    fontWeight: FontWeight.bold,
                  ),
                  blockSpacing: 8,
                ),
              ),
            if (hasDeadline && !isUser) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 16,
                          color: AppColors.primaryForeground,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Deadline Detected',
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryForeground,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      metadata['formatted_date'] as String? ?? 'Upcoming deadline',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => _syncToCalendar(metadata),
                          icon: const Icon(Icons.add_alert_rounded, size: 14),
                          label: const Text('Add to Calendar', style: TextStyle(fontSize: 11.5)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: '${metadata['task_title']}: ${metadata['formatted_date']}',
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Due date copied!')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Copy Due Date', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Assistant"),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: "Clear chat",
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ChatBackground(
              child: _messages.isEmpty
                  ? _buildWelcome()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Campuz AI is thinking...",
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: "Ask AI or paste an announcement...",
                        hintStyle: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceMuted,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (context, val, _) {
                      final hasText = val.text.trim().isNotEmpty;
                      return Container(
                        decoration: BoxDecoration(
                          color: (hasText && !_isTyping)
                              ? AppColors.primary
                              : AppColors.surfaceMuted,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_upward,
                            color: (hasText && !_isTyping)
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          onPressed: (hasText && !_isTyping)
                              ? () => _sendMessage()
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}