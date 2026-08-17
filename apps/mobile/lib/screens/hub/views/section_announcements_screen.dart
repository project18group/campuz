import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class SectionAnnouncementsScreen extends StatefulWidget {
  final int hubId;
  final Map<String, dynamic> section;
  final Map<String, dynamic>? hub;

  const SectionAnnouncementsScreen({
    super.key,
    required this.hubId,
    required this.section,
    this.hub,
  });

  @override
  State<SectionAnnouncementsScreen> createState() =>
      _SectionAnnouncementsScreenState();
}

class _SectionAnnouncementsScreenState
    extends State<SectionAnnouncementsScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<Map<String, dynamic>> _announcements = [];

  bool _isLoading = true;
  bool _isCreating = false;
  bool _sendAsSms = false;
  String _priority = 'normal';
  String? _error;
  Timer? _pollTimer;

  String get _sectionTitle =>
      (widget.section['title'] as String? ?? 'Announcements').trim();

  bool get _canCreateBroadcasts => widget.hub?['can_manage_members'] == true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadAnnouncements(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await AuthApiService.getHubBroadcasts(hubId: widget.hubId);
      final items = _extractResults(response);
      if (!mounted) return;
      setState(() {
        _announcements
          ..clear()
          ..addAll(items);
        _isLoading = false;
        _error = null;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = error.message;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'Unable to load announcements right now.';
          _isLoading = false;
        });
      }
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

  String _senderName(Map<String, dynamic> broadcast) {
    final sender = broadcast['sender'] as Map<String, dynamic>? ?? const {};
    final profile = sender['profile'] as Map<String, dynamic>? ?? const {};
    final senderName = (broadcast['sender_name'] as String? ?? '').trim();
    if (senderName.isNotEmpty) return senderName;
    final displayName = (profile['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (profile['full_name'] as String? ?? '').trim();
    return fullName.isNotEmpty ? fullName : 'Campuz user';
  }

  DateTime? _parseTimestamp(Map<String, dynamic> broadcast) {
    final raw = broadcast['timestamp'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _formatTimestamp(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority) {
      case 'high':
        return Icons.priority_high;
      case 'low':
        return Icons.info_outline;
      default:
        return Icons.campaign_outlined;
    }
  }

  Widget _buildCard(Map<String, dynamic> broadcast) {
    final title = (broadcast['title'] as String? ?? '').trim();
    final content = (broadcast['content'] as String? ?? '').trim();
    final senderName = _senderName(broadcast);
    final timestamp = _formatTimestamp(_parseTimestamp(broadcast));
    final priority = (broadcast['priority'] as String? ?? 'normal').trim();

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: priority == 'high'
              ? _priorityColor(priority).withValues(alpha: 0.3)
              : AppColors.border,
          width: priority == 'high' ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _priorityColor(priority).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    _priorityIcon(priority),
                    size: 20,
                    color: _priorityColor(priority),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Posted by $senderName',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (priority == 'high')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryForeground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'URGENT',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(content, style: AppTextStyles.body),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  timestamp,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBroadcast(
    BuildContext sheetContext,
    StateSetter setSheetState,
  ) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty || _isCreating) return;

    setSheetState(() {
      _isCreating = true;
    });
    try {
      final result = await AuthApiService.createHubBroadcast(
        hubId: widget.hubId,
        title: title,
        content: content,
        priority: _priority,
        sendAsSms: _sendAsSms && _canCreateBroadcasts,
      );
      if (!mounted) return;
      final broadcast = result;
      setState(() {
        _announcements.insert(0, Map<String, dynamic>.from(broadcast));
              _isCreating = false;
      });
      _titleController.clear();
      _contentController.clear();
      _priority = 'normal';
      _sendAsSms = false;
      if (!context.mounted) return;
      if (Navigator.of(sheetContext).canPop()) {
        Navigator.of(sheetContext).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement posted successfully.')),
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setSheetState(() {
        _isCreating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setSheetState(() {
        _isCreating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create announcement right now')),
      );
    }
  }

  void _openComposer() {
    if (!_canCreateBroadcasts) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Create broadcast',
                        style: AppTextStyles.heading.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Content',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'normal', child: Text('Normal')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => _priority = value);
                          setState(() => _priority = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final smsCredits = (widget.hub?['sms_credits'] as num?)?.toInt() ?? 0;
                          final canSendSms = smsCredits > 0;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Send as SMS',
                                      style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Balance: $smsCredits credits',
                                      style: AppTextStyles.caption.copyWith(
                                        color: canSendSms ? AppColors.textSecondary : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _sendAsSms && canSendSms,
                                onChanged: canSendSms
                                    ? (value) {
                                        setSheetState(() => _sendAsSms = value);
                                        setState(() => _sendAsSms = value);
                                      }
                                    : null,
                              ),
                            ],
                          );
                        }
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isCreating
                              ? null
                              : () => _createBroadcast(sheetContext, setSheetState),
                          child: _isCreating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Publish broadcast'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody() {
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
              Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadAnnouncements,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_announcements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No announcements',
                style: AppTextStyles.heading.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back later for updates',
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
      onRefresh: _loadAnnouncements,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _announcements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildCard(_announcements[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_sectionTitle, style: AppTextStyles.label),
            Text(
              'Important Updates',
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadAnnouncements,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _canCreateBroadcasts
          ? FloatingActionButton.extended(
              onPressed: _openComposer,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('New broadcast'),
            )
          : null,
      body: _buildBody(),
    );
  }
}