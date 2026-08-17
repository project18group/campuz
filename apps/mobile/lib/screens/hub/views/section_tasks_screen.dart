import 'dart:async';

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class SectionTasksScreen extends StatefulWidget {
  final int hubId;
  final Map<String, dynamic> section;
  final Map<String, dynamic>? hub;

  const SectionTasksScreen({
    super.key,
    required this.hubId,
    required this.section,
    this.hub,
  });

  @override
  State<SectionTasksScreen> createState() => _SectionTasksScreenState();
}

class _SectionTasksScreenState extends State<SectionTasksScreen> {
  final List<Map<String, dynamic>> _tasks = [];
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _courseController = TextEditingController();
  final _submissionTextController = TextEditingController();
  final _submissionLinkController = TextEditingController();
  final _gradeController = TextEditingController();
  final _feedbackController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  final bool _isSubmitting = false;
  String? _error;
  String _filter = 'all';
  Timer? _pollTimer;
  int? _selectedAssigneeId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));

  String get _sectionTitle =>
      (widget.section['title'] as String? ?? 'Tasks').trim();

  bool get _canManageTasks => widget.hub?['can_manage_members'] == true;

  List<Map<String, dynamic>> get _members {
    final raw = widget.hub?['members'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadTasks(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _courseController.dispose();
    _submissionTextController.dispose();
    _submissionLinkController.dispose();
    _gradeController.dispose();
    _feedbackController.dispose();
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
      final response = await AuthApiService.getHubTasks(
        hubId: widget.hubId,
        status: _filter,
        mine: !_canManageTasks,
      );
      final items = _extractResults(response)
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

  String _displayName(Map<String, dynamic> task) {
    final assignedTo = task['assigned_to'] as Map<String, dynamic>? ?? const {};
    final profile = assignedTo['profile'] as Map<String, dynamic>? ?? const {};
    final assignedName = (task['assigned_to_name'] as String? ?? '').trim();
    if (assignedName.isNotEmpty) return assignedName;
    final displayName = (profile['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (profile['full_name'] as String? ?? '').trim();
    return fullName.isNotEmpty ? fullName : 'Campuz user';
  }

  String _gradedByName(Map<String, dynamic> task) {
    final name = (task['graded_by_name'] as String? ?? '').trim();
    return name.isNotEmpty ? name : 'Campuz user';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Date not set';
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year} • ${TimeOfDay.fromDateTime(local).format(context)}';
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays < 0) {
      final days = difference.inDays.abs();
      return '$days day${days == 1 ? '' : 's'} ago';
    }
    if (difference.inHours < 24) {
      if (difference.inHours < 1) {
        return 'in ${difference.inMinutes} minutes';
      }
      return 'in ${difference.inHours} hours';
    }
    if (difference.inDays < 7) {
      return 'in ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isOverdue(Map<String, dynamic> task) {
    final dueDate = _parseDueDate(task);
    final status = (task['status'] as String? ?? '').trim().toLowerCase();
    return status == 'pending' && dueDate != null && DateTime.now().isAfter(dueDate);
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

  List<Map<String, dynamic>> get _filteredTasks {
    if (_filter == 'all') return _tasks;
    return _tasks.where((task) => task['status'] == _filter).toList();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final id = task['id'] is int ? task['id'] as int : int.tryParse('${task['id']}');
    if (id == null || _isSaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete task'),
          content: const Text('This will permanently remove the task from the hub.'),
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
      await AuthApiService.deleteHubTask(taskId: id);
      if (!mounted) return;
      setState(() => _isSaving = false);
      await _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted.')),
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
        const SnackBar(content: Text('Unable to delete task right now.')),
      );
    }
  }

  Future<void> _pickDueDateTime(StateSetter setSheetState, DateTime current) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (pickedTime == null) return;
    setSheetState(() {
      _dueDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _openTaskSheet({Map<String, dynamic>? task}) async {
    if (!_canManageTasks) return;

    final isEditing = task != null;
    _titleController.text = (task?['title'] as String? ?? '').trim();
    _descriptionController.text = (task?['description'] as String? ?? '').trim();
    _courseController.text = (task?['course_name'] as String? ?? '').trim();
    _submissionTextController.text = (task?['submission_text'] as String? ?? '').trim();
    _submissionLinkController.text = (task?['submission_link'] as String? ?? '').trim();
    _gradeController.text = (task?['grade'] as String? ?? '').trim();
    _feedbackController.text = (task?['feedback'] as String? ?? '').trim();
    _selectedAssigneeId = task?['assigned_to'] is Map<String, dynamic>
        ? (task?['assigned_to'] as Map<String, dynamic>)['id'] as int?
        : null;
    _dueDate = _parseDueDate(task ?? const {}) ?? DateTime.now().add(const Duration(days: 3));
    bool sending = false;
    File? selectedAttachment;

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
              final title = _titleController.text.trim();
              final description = _descriptionController.text.trim();
              final courseName = _courseController.text.trim();
              final assigneeId = _selectedAssigneeId;
              if (title.isEmpty || courseName.isEmpty || assigneeId == null || sending) {
                return;
              }

              setSheetState(() => sending = true);
              try {
                if (isEditing) {
                  final id = task['id'] is int ? task['id'] as int : int.tryParse('${task['id']}');
                  if (id == null) throw const AuthApiException('Invalid task id.');
                  await AuthApiService.updateHubTask(
                    taskId: id,
                    title: title,
                    description: description,
                    courseName: courseName,
                    dueDate: _dueDate,
                    assignedToId: assigneeId,
                    status: (task['status'] as String? ?? 'pending'),
                  );
                } else {
                  await AuthApiService.createHubTask(
                    hubId: widget.hubId,
                    title: title,
                    description: description,
                    courseName: courseName,
                    dueDate: _dueDate,
                    assignedToId: assigneeId,
                    attachment: selectedAttachment,
                  );
                }

                if (!context.mounted) return;
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).pop();
                }
                await _loadTasks();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEditing ? 'Task updated.' : 'Task created.'),
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
                      isEditing ? 'Unable to update task right now.' : 'Unable to create task right now.',
                    ),
                  ),
                );
              }
            }

            final bottomPadding = MediaQuery.of(context).viewInsets.bottom + 20;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: bottomPadding,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEditing ? 'Edit task' : 'Create task',
                        style: AppTextStyles.heading.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _courseController,
                        decoration: const InputDecoration(labelText: 'Course / Class'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedAssigneeId,
                        decoration: const InputDecoration(labelText: 'Assign to'),
                        items: _members
                            .map<DropdownMenuItem<int>?>((member) {
                              final user = member['user'] as Map<String, dynamic>? ?? const {};
                              final profile = user['profile'] as Map<String, dynamic>? ?? const {};
                              final id = user['id'];
                              if (id is! int) return null;
                              final name = (profile['display_name'] as String? ?? '').trim();
                              final fullName = (profile['full_name'] as String? ?? '').trim();
                              final label = name.isNotEmpty
                                  ? name
                                  : fullName.isNotEmpty
                                      ? fullName
                                      : (user['username'] as String? ?? 'Member');
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(label),
                              );
                            })
                            .whereType<DropdownMenuItem<int>>()
                            .toList(),
                        onChanged: (value) => setSheetState(() => _selectedAssigneeId = value),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDueDateTime(setSheetState, _dueDate),
                              icon: const Icon(Icons.schedule_outlined),
                              label: const Text('Due date'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDateTime(_dueDate),
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
                              : Text(isEditing ? 'Save task' : 'Create task'),
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

  Future<void> _submitTask(Map<String, dynamic> task) async {
    final id = task['id'] is int ? task['id'] as int : int.tryParse('${task['id']}');
    if (id == null || _isSubmitting) return;

    final submissionTextController = TextEditingController(
      text: (task['submission_text'] as String? ?? '').trim(),
    );
    final submissionLinkController = TextEditingController(
      text: (task['submission_link'] as String? ?? '').trim(),
    );
    bool sending = false;
    File? submissionFile;

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
                  submissionText: submissionTextController.text.trim(),
                  submissionLink: submissionLinkController.text.trim(),
                  submissionFile: submissionFile,
                );
                if (!context.mounted) return;
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).pop();
                }
                await _loadTasks();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task submitted.')),
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
                        controller: submissionTextController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Submission notes',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: submissionLinkController,
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

    submissionTextController.dispose();
    submissionLinkController.dispose();
  }

  Future<void> _gradeTask(Map<String, dynamic> task) async {
    final id = task['id'] is int ? task['id'] as int : int.tryParse('${task['id']}');
    if (id == null) return;

    _gradeController.text = (task['grade'] as String? ?? '').trim();
    _feedbackController.text = (task['feedback'] as String? ?? '').trim();
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
              final grade = _gradeController.text.trim();
              if (grade.isEmpty || sending) return;
              setSheetState(() => sending = true);
              try {
                await AuthApiService.gradeHubTask(
                  taskId: id,
                  grade: grade,
                  feedback: _feedbackController.text.trim(),
                );
                if (!context.mounted) return;
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).pop();
                }
                await _loadTasks();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task graded.')),
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
                  const SnackBar(content: Text('Unable to grade task right now.')),
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
                        'Grade task',
                        style: AppTextStyles.heading.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _gradeController,
                        decoration: const InputDecoration(labelText: 'Grade / score'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _feedbackController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Feedback'),
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
                              : const Text('Save grade'),
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

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = (task['title'] as String? ?? '').trim();
    final courseName = (task['course_name'] as String? ?? '').trim();
    final dueDate = _parseDueDate(task);
    final status = (task['status'] as String? ?? 'pending').trim().toLowerCase();
    final assigneeName = _displayName(task);
    final gradedBy = _gradedByName(task);
    final submissionText = (task['submission_text'] as String? ?? '').trim();
    final submissionLink = (task['submission_link'] as String? ?? '').trim();
    final grade = (task['grade'] as String? ?? '').trim();
    final feedback = (task['feedback'] as String? ?? '').trim();
    final canManage = task['can_manage'] == true || _canManageTasks;
    final canSubmit = task['can_submit'] == true;
    final isOverdue = _isOverdue(task);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isOverdue
              ? Colors.red.withValues(alpha: 0.22)
              : AppColors.border,
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
                if (canManage)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openTaskSheet(task: task);
                      } else if (value == 'grade') {
                        _gradeTask(task);
                      } else if (value == 'delete') {
                        _deleteTask(task);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'grade', child: Text('Grade')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
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
                    _canManageTasks ? 'Assigned to $assigneeName' : 'For $assigneeName',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                    if (gradedBy.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Graded by $gradedBy',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (canSubmit && !_canManageTasks)
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : () => _submitTask(task),
                      child: const Text('Submit Task'),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      'Status updates are managed by the hub.',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (!_canManageTasks && canSubmit) const SizedBox(width: 12),
                if (!_canManageTasks && canSubmit && submissionLink.isNotEmpty)
                  TextButton(
                    onPressed: () => _openUrl(submissionLink),
                    child: const Text('View link'),
                  ),
              ],
            ),
          ],
        ),
      ),
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
                onPressed: _loadTasks,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredTasks.isEmpty) {
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
                        _canManageTasks
                            ? 'Create the first assignment for this hub.'
                            : 'No tasks match the current filter.',
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
        itemCount: _filteredTasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _buildTaskCard(_filteredTasks[index]),
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
              _canManageTasks ? 'Task management' : 'Your assignments',
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadTasks,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _canManageTasks
          ? FloatingActionButton.extended(
              onPressed: () => _openTaskSheet(),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('New task'),
            )
          : null,
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}