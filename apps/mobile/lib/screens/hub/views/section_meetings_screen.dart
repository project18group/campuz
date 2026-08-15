import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class SectionMeetingsScreen extends StatefulWidget {
  final int hubId;
  final Map<String, dynamic> section;
  final Map<String, dynamic>? hub;

  const SectionMeetingsScreen({
    super.key,
    required this.hubId,
    required this.section,
    this.hub,
  });

  @override
  State<SectionMeetingsScreen> createState() => _SectionMeetingsScreenState();
}

class _SectionMeetingsScreenState extends State<SectionMeetingsScreen> {
  final List<Map<String, dynamic>> _meetings = [];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  Timer? _pollTimer;

  String get _sectionTitle =>
      (widget.section['title'] as String? ?? 'Meetings').trim();

  String get _displaySectionTitle {
    return _sectionTitle.toLowerCase() == 'meetings'
        ? 'Scheduled Sessions'
        : _sectionTitle;
  }

  bool get _canManageMeetings => widget.hub?['can_manage_members'] == true;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadMeetings(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMeetings({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await AuthApiService.getHubMeetings(hubId: widget.hubId);
      final items = _extractResults(response)
        ..sort((a, b) {
          final aDate = _parseScheduledFor(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = _parseScheduledFor(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        });
      if (!mounted) return;
      setState(() {
        _meetings
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
          _error = 'Unable to load meetings right now.';
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

  String _displayName(Map<String, dynamic> meeting) {
    final creator = meeting['created_by'] as Map<String, dynamic>? ?? const {};
    final profile = creator['profile'] as Map<String, dynamic>? ?? const {};
    final creatorName = (meeting['created_by_name'] as String? ?? '').trim();
    if (creatorName.isNotEmpty) return creatorName;
    final displayName = (profile['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (profile['full_name'] as String? ?? '').trim();
    return fullName.isNotEmpty ? fullName : 'Campuz user';
  }

  DateTime? _parseScheduledFor(Map<String, dynamic> meeting) {
    final raw = meeting['scheduled_for'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _formatDateTime(BuildContext context, DateTime? scheduledFor) {
    if (scheduledFor == null) return 'Time not set';
    final local = scheduledFor.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final meetingDay = DateTime(local.year, local.month, local.day);
    final tomorrow = today.add(const Duration(days: 1));
    final timeLabel = TimeOfDay.fromDateTime(local).format(context);

    if (meetingDay == today) {
      return 'Today • $timeLabel';
    }
    if (meetingDay == tomorrow) {
      return 'Tomorrow • $timeLabel';
    }
    return '${local.day}/${local.month}/${local.year} • $timeLabel';
  }

  Future<void> _openMeeting(Map<String, dynamic> meeting) async {
    final url = (meeting['meeting_url'] as String? ?? '').trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No session link is available.')),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid session link.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open session link.')),
      );
    }
  }

  Future<void> _deleteMeeting(Map<String, dynamic> meeting) async {
    final meetingId = meeting['id'];
    final id = meetingId is int ? meetingId : int.tryParse('$meetingId');
    if (id == null || _isSaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete session'),
          content: const Text(
            'This will remove the session from the hub for all members.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Delete',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await AuthApiService.deleteHubMeeting(meetingId: id);
      if (!mounted) return;
      setState(() => _isSaving = false);
      await _loadMeetings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session deleted.')),
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete meeting right now.')),
      );
    }
  }

  Future<void> _openMeetingSheet({Map<String, dynamic>? meeting}) async {
    if (!_canManageMeetings) return;

    final isEditing = meeting != null;
    final titleController =
        TextEditingController(text: (meeting?['title'] as String? ?? '').trim());
    final descriptionController = TextEditingController(
      text: (meeting?['description'] as String? ?? '').trim(),
    );
    final urlController = TextEditingController(
      text: (meeting?['meeting_url'] as String? ?? '').trim(),
    );
    final scheduledAt =
        (meeting != null ? _parseScheduledFor(meeting) : null) ??
            DateTime.now().add(const Duration(hours: 1));
    DateTime selectedDateTime = scheduledAt.toLocal();
    bool sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: sheetContext,
                initialDate: selectedDateTime,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (picked == null) return;
              setSheetState(() {
                selectedDateTime = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  selectedDateTime.hour,
                  selectedDateTime.minute,
                );
              });
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: sheetContext,
                initialTime: TimeOfDay.fromDateTime(selectedDateTime),
              );
              if (picked == null) return;
              setSheetState(() {
                selectedDateTime = DateTime(
                  selectedDateTime.year,
                  selectedDateTime.month,
                  selectedDateTime.day,
                  picked.hour,
                  picked.minute,
                );
              });
            }

            Future<void> submit() async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              final url = urlController.text.trim();
              if (title.isEmpty || url.isEmpty || sending) return;

              setSheetState(() => sending = true);
              try {
                if (isEditing) {
                  final meetingId = meeting['id'];
                  final id = meetingId is int ? meetingId : int.tryParse('$meetingId');
                  if (id == null) {
                    throw const AuthApiException('Invalid meeting id.');
                  }
                  await AuthApiService.updateHubMeeting(
                    meetingId: id,
                    title: title,
                    description: description,
                    meetingUrl: url,
                    scheduledFor: selectedDateTime.toUtc().toIso8601String(),
                  );
                } else {
                  await AuthApiService.createHubMeeting(
                    hubId: widget.hubId,
                    title: title,
                    description: description,
                    meetingUrl: url,
                    scheduledFor: selectedDateTime.toUtc().toIso8601String(),
                  );
                }

                if (!context.mounted) return;
                setState(() => _isSaving = false);
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).pop();
                }
                await _loadMeetings();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing ? 'Meeting updated.' : 'Meeting created.',
                    ),
                  ),
                );
              } on AuthApiException catch (error) {
                if (!context.mounted) return;
                setSheetState(() => sending = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.message)),
                );
              } catch (_) {
                if (!context.mounted) return;
                setSheetState(() => sending = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? 'Unable to update session right now.'
                          : 'Unable to create session right now.',
                    ),
                  ),
                );
              }
            }

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
                        isEditing ? 'Edit session' : 'Create session',
                        style: AppTextStyles.heading.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(labelText: 'Session URL'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickDate,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: const Text('Date'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickTime,
                              icon: const Icon(Icons.schedule_outlined),
                              label: const Text('Time'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatDateTime(context, selectedDateTime),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: sending ? null : submit,
                          child: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(isEditing ? 'Save changes' : 'Create session'),
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

    titleController.dispose();
    descriptionController.dispose();
    urlController.dispose();
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final title = (meeting['title'] as String? ?? '').trim();
    final description = (meeting['description'] as String? ?? '').trim();
    final creatorName = _displayName(meeting);
    final scheduledFor = _parseScheduledFor(meeting);
    final canManage = meeting['can_manage'] == true || _canManageMeetings;
    final isUpcoming = meeting['is_upcoming'] == true;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isUpcoming
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.video_call_outlined,
                    color: AppColors.primaryDeep,
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
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(context, scheduledFor),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openMeetingSheet(meeting: meeting);
                      } else if (value == 'delete') {
                        _deleteMeeting(meeting);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description, style: AppTextStyles.body),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Created by $creatorName',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openMeeting(meeting),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Join Session'),
              ),
            ),
          ],
        ),
      ),
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
                onPressed: _loadMeetings,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_meetings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMeetings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.video_call_outlined,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No scheduled sessions',
                        style: AppTextStyles.heading.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _canManageMeetings
                            ? 'Create the first session for this hub.'
                            : 'Check back later for the next scheduled session.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
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

    return RefreshIndicator(
      onRefresh: _loadMeetings,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _meetings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _buildMeetingCard(_meetings[index]),
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
            Text(_displaySectionTitle, style: AppTextStyles.label),
            Text(
              'Upcoming sessions',
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadMeetings,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _canManageMeetings
          ? FloatingActionButton.extended(
              onPressed: () => _openMeetingSheet(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('New session'),
            )
          : null,
      body: _buildBody(),
    );
  }
}