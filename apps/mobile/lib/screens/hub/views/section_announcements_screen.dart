import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class SectionAnnouncementsScreen extends StatefulWidget {
  final int hubId;
  final Map<String, dynamic> section;

  const SectionAnnouncementsScreen({
    super.key,
    required this.hubId,
    required this.section,
  });

  @override
  State<SectionAnnouncementsScreen> createState() =>
      _SectionAnnouncementsScreenState();
}

class _SectionAnnouncementsScreenState
    extends State<SectionAnnouncementsScreen> {
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  String? _error;

  String get _sectionTitle =>
      (widget.section['title'] as String? ?? 'Announcements').trim();

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // TODO: Call API to fetch announcements
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _announcements = [
          {
            'id': 1,
            'title': 'Midterm Exam Schedule',
            'content':
                'The midterm examination will be held on Friday, August 15th at 9:00 AM in Room 204. Please arrive 15 minutes early.',
            'sender_name': 'Dr. Mensah',
            'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
            'priority': 'high',
          },
          {
            'id': 2,
            'title': 'Project Submission Reminder',
            'content':
                'Don\'t forget to submit your group projects by next Monday. Late submissions will incur a penalty.',
            'sender_name': 'Prof. Asante',
            'timestamp': DateTime.now().subtract(const Duration(days: 1)),
            'priority': 'normal',
          },
          {
            'id': 3,
            'title': 'Guest Lecture Next Week',
            'content':
                'We have a special guest lecturer from Google coming next Wednesday. Attendance is highly encouraged.',
            'sender_name': 'Dr. Mensah',
            'timestamp': DateTime.now().subtract(const Duration(days: 2)),
            'priority': 'normal',
          },
        ];
        _isLoading = false;
      });
    }
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
      ),
      body: _buildBody(),
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
        itemBuilder: (context, index) =>
            _buildAnnouncementCard(_announcements[index]),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final title = announcement['title'] as String;
    final content = announcement['content'] as String;
    final senderName = announcement['sender_name'] as String;
    final timestamp = announcement['timestamp'] as DateTime;
    final priority = announcement['priority'] as String;

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
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: AppTextStyles.body,
            ),
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
                  _formatTimestamp(timestamp),
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

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
