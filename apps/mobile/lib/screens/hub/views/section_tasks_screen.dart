import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class SectionTasksScreen extends StatefulWidget {
  final int hubId;
  final Map<String, dynamic> section;

  const SectionTasksScreen({
    super.key,
    required this.hubId,
    required this.section,
  });

  @override
  State<SectionTasksScreen> createState() => _SectionTasksScreenState();
}

class _SectionTasksScreenState extends State<SectionTasksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all';

  String get _sectionTitle =>
      (widget.section['title'] as String? ?? 'Tasks').trim();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // TODO: Call API to fetch tasks
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _tasks = [
          {
            'id': 1,
            'title': 'Complete Chapter 5 Exercises',
            'course_name': 'Data Structures',
            'due_date': DateTime.now().add(const Duration(days: 2)),
            'status': 'pending',
          },
          {
            'id': 2,
            'title': 'Group Project Presentation',
            'course_name': 'Software Engineering',
            'due_date': DateTime.now().add(const Duration(days: 5)),
            'status': 'pending',
          },
          {
            'id': 3,
            'title': 'Lab Report #3',
            'course_name': 'Computer Networks',
            'due_date': DateTime.now().subtract(const Duration(days: 1)),
            'status': 'submitted',
          },
          {
            'id': 4,
            'title': 'Quiz Preparation',
            'course_name': 'Algorithms',
            'due_date': DateTime.now().add(const Duration(hours: 18)),
            'status': 'pending',
          },
          {
            'id': 5,
            'title': 'Final Project Proposal',
            'course_name': 'Software Engineering',
            'due_date': DateTime.now().subtract(const Duration(days: 5)),
            'status': 'graded',
          },
        ];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredTasks {
    if (_filter == 'all') return _tasks;
    return _tasks.where((t) => t['status'] == _filter).toList();
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
    final dueDate = task['due_date'] as DateTime;
    final status = task['status'] as String;
    return status == 'pending' && DateTime.now().isAfter(dueDate);
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
              'Assignments & Deadlines',
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('To Do', 'pending'),
            const SizedBox(width: 8),
            _buildFilterChip('Submitted', 'submitted'),
            const SizedBox(width: 8),
            _buildFilterChip('Graded', 'graded'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = value;
        });
      },
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primaryDeep,
      labelStyle: AppTextStyles.body.copyWith(
        fontSize: 14,
        color: isSelected ? AppColors.primaryDeep : AppColors.text,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
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
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.textSecondary,
              ),
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

    final filtered = _filteredTasks;

    if (filtered.isEmpty) {
      return Center(
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
                _filter == 'all'
                    ? 'No tasks have been assigned yet'
                    : 'No $_filter tasks found',
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
      onRefresh: _loadTasks,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildTaskCard(filtered[index]),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = task['title'] as String;
    final courseName = task['course_name'] as String;
    final dueDate = task['due_date'] as DateTime;
    final status = task['status'] as String;
    final isOverdue = _isOverdue(task);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue
              ? Colors.red.withValues(alpha: 0.3)
              : AppColors.border,
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening $title...')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _statusColor(status).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(status),
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
                    isOverdue
                        ? 'Overdue'
                        : 'Due ${_formatDueDate(dueDate)}',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: isOverdue ? Colors.red : AppColors.textSecondary,
                      fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
}
