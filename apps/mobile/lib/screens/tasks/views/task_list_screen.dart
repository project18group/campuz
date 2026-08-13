import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final List<Map<String, dynamic>> _tasks = [];
  final _submissionTextController = TextEditingController();
  final _submissionLinkController = TextEditingController();
  bool _isLoading = true;
  final bool _isSubmitting = false;
  String? _error;
  String _filter = 'all';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadTasks(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _submissionTextController.dispose();
    _submissionLinkController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await AuthApiService.getTasks(status: _filter, mine: true);
      final items = response
        ..sort((a, b) {
          final aDate = _parseDueDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = _parseDueDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        });
      if (!mounted) return;
      setState(() {
        _tasks
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
          _error = 'Unable to load tasks right now.';
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

  DateTime? _parseDueDate(Map<String, dynamic> task) {
    final raw = task['due_date'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays < 0) {
      final days = difference.inDays.abs();
      return '$days day${days == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      if (difference.inHours < 1) {
        return 'in ${difference.inMinutes} minutes';
      }
      return 'in ${difference.inHours} hours';
    } else if (difference.inDays < 7) {
      return 'in ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      case 'graded':
        return Colors.green;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'To Do';
      case 'submitted':
        return 'Submitted';
      case 'graded':
        return 'Graded';
      default:
        return status;
    }
  }

  bool _isOverdue(Map<String, dynamic> task) {
    final dueDate = _parseDueDate(task);
    final status = (task['status'] as String? ?? '').trim().toLowerCase();
    return status == 'pending' && dueDate != null && DateTime.now().isAfter(dueDate);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submitTask(Map<String, dynamic> task) async {
    final id = task['id'] is int ? task['id'] as int : int.tryParse('${task['id']}');
    if (id == null || _isSubmitting) return;

    _submissionTextController.text = (task['submission_text'] as String? ?? '').trim();
    _submissionLinkController.text = (task['submission_link'] as String? ?? '').trim();
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
            Future<void> submit() async {
              if (sending) return;
              setSheetState(() => sending = true);
              try {
                await AuthApiService.submitHubTask(
                  taskId: id,
                  submissionText: _submissionTextController.text.trim(),
                  submissionLink: _submissionLinkController.text.trim(),
                );
                if (!mounted) return;
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).pop();
                }
                await _loadTasks();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task submitted.')),
                );
              } on AuthApiException catch (error) {
                if (!mounted) return;
                setSheetState(() => sending = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.message)),
                );
              } catch (_) {
                if (!mounted) return;
                setSheetState(() => sending = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to submit task right now.')),
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
                        'Submit task',
                        style: AppTextStyles.heading.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _submissionTextController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Submission notes',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _submissionLinkController,
                        decoration: const InputDecoration(labelText: 'Submission link'),
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
                              : const Text('Submit'),
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

  Widget _buildFilterChips() {
    final chips = const [
      ('All', 'all'),
      ('To Do', 'pending'),
      ('Submitted', 'submitted'),
      ('Graded', 'graded'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((chip) {
            final label = chip.$1;
            final value = chip.$2;
            final selected = _filter == value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) {
                  setState(() => _filter = value);
                  _loadTasks();
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = (task['title'] as String? ?? '').trim();
    final courseName = (task['course_name'] as String? ?? '').trim();
    final dueDate = _parseDueDate(task);
    final status = (task['status'] as String? ?? 'pending').trim().toLowerCase();
    final submissionLink = (task['submission_link'] as String? ?? '').trim();
    final submissionText = (task['submission_text'] as String? ?? '').trim();
    final grade = (task['grade'] as String? ?? '').trim();
    final feedback = (task['feedback'] as String? ?? '').trim();
    final isOverdue = _isOverdue(task);
    final canSubmit = task['can_submit'] == true;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isOverdue ? Colors.red.withValues(alpha: 0.22) : AppColors.border,
          width: isOverdue ? 1.4 : 1,
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
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isOverdue ? Icons.error_outline : Icons.task_alt_outlined,
                    color: isOverdue ? Colors.red : _statusColor(status),
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
                        courseName,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: AppTextStyles.caption.copyWith(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isOverdue ? Icons.error_outline : Icons.access_time,
                  size: 16,
                  color: isOverdue ? Colors.red : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  isOverdue ? 'Overdue' : 'Due ${_formatDueDate(dueDate ?? DateTime.now())}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    color: isOverdue ? Colors.red : AppColors.textSecondary,
                    fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            if (submissionText.isNotEmpty || submissionLink.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submission',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (submissionText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(submissionText, style: AppTextStyles.body),
                    ],
                    if (submissionLink.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _openUrl(submissionLink),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open submission link'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (status == 'graded' || grade.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grade: ${grade.isEmpty ? 'Not set' : grade}',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (feedback.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(feedback, style: AppTextStyles.body),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (canSubmit)
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : () => _submitTask(task),
                      child: const Text('Submit Task'),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      'No action needed',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (canSubmit && submissionLink.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => _openUrl(submissionLink),
                    child: const Text('View link'),
                  ),
                ],
              ],
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
              const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadTasks,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTasks,
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
                        Icons.task_alt_outlined,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tasks',
                        style: AppTextStyles.heading.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No tasks match the current filter.',
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
      onRefresh: _loadTasks,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _buildTaskCard(_tasks[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks & Assignments')),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
