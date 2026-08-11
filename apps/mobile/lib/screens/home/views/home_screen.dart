import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/home/widgets/empty_home_state.dart';
import 'package:mobile/shared/widgets/app_fab.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _hubs = const [];
  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _broadcasts = const [];
  List<Map<String, dynamic>> _resources = const [];
  List<Map<String, dynamic>> _tasks = const [];
  List<Map<String, dynamic>> _meetings = const [];
  bool _isLoading = true;
  String? _error;

  bool get _isEmpty =>
      _hubs.isEmpty &&
      _conversations.isEmpty &&
      _broadcasts.isEmpty &&
      _resources.isEmpty &&
      _tasks.isEmpty &&
      _meetings.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AuthApiService.getHubs(),
        AuthApiService.getDirectConversations(),
        AuthApiService.getBroadcasts(),
        AuthApiService.getResources(),
        AuthApiService.getTasks(),
        AuthApiService.getMeetings(),
      ]);
      if (mounted) {
        setState(() {
          _hubs = results[0];
          _conversations = results[1];
          _broadcasts = results[2];
          _resources = results[3];
          _tasks = results[4];
          _meetings = results[5];
          _isLoading = false;
        });
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = error.message;
        });
      }
    }
  }

  String _conversationName(Map<String, dynamic> conversation) {
    final user = conversation['other_user'] as Map<String, dynamic>? ?? const {};
    final displayName = (user['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (user['full_name'] as String? ?? '').trim();
    return fullName.isEmpty ? 'Campuz user' : fullName;
  }

  String _hubName(int? hubId) {
    if (hubId == null) return 'Hub';
    for (final hub in _hubs) {
      if (hub['id'] == hubId) {
        return (hub['name'] as String? ?? 'Hub').trim();
      }
    }
    return 'Hub';
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final now = DateTime.now();
    final sameDay = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    if (sameDay) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month}';
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  IconData _resourceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'video':
        return Icons.play_circle_fill_rounded;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _resourceColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFE53935);
      case 'document':
        return const Color(0xFF1E88E5);
      case 'video':
        return const Color(0xFFFB8C00);
      case 'link':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.primaryDeep;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFE53935);
      case 'normal':
        return const Color(0xFF1E88E5);
      case 'low':
        return const Color(0xFF14A44D);
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Campuz',
          style: AppTextStyles.heading.copyWith(fontSize: 25),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/select-contact'),
          ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: AppFab(
        onPressed: () async {
          await context.push('/select-contact');
          if (mounted) _loadHome();
        },
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
              const Icon(
                Icons.cloud_off_outlined,
                size: 52,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 14),
              Text('Unable to load Campuz', style: AppTextStyles.heading),
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
                onPressed: _loadHome,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_isEmpty) {
      return const EmptyHomeState(key: ValueKey('home-empty-state'));
    }

    return RefreshIndicator(
      onRefresh: _loadHome,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _overviewCard(),
          const SizedBox(height: 16),
          _summarySection(
            title: 'Recent Messages',
            subtitle: 'Latest conversation updates from your network.',
            emptyTitle: 'No messages yet',
            emptyBody: 'Start a direct chat to see message previews here.',
            children: _conversations.take(3).map(_recentMessageCard).toList(),
          ),
          const SizedBox(height: 14),
          _summarySection(
            title: 'Announcements',
            subtitle: 'Priority broadcasts from your hubs.',
            emptyTitle: 'No announcements',
            emptyBody: 'When admins post updates, they will appear here.',
            children: _broadcasts.take(3).map(_announcementCard).toList(),
          ),
          const SizedBox(height: 14),
          _summarySection(
            title: 'Resources',
            subtitle: 'Shared files and useful links.',
            emptyTitle: 'No resources',
            emptyBody: 'Hub uploads and links will show up here.',
            children: _resources.take(3).map(_resourceCard).toList(),
          ),
          const SizedBox(height: 14),
          _summarySection(
            title: 'Tasks',
            subtitle: 'Your most recent assignments.',
            emptyTitle: 'No tasks',
            emptyBody: 'Assigned work will appear here once added.',
            children: _tasks.take(3).map(_taskCard).toList(),
          ),
          const SizedBox(height: 14),
          _summarySection(
            title: 'Meetings',
            subtitle: 'Upcoming Zoom or external sessions.',
            emptyTitle: 'No meetings',
            emptyBody: 'Scheduled meetings from your hubs will show here.',
            children: _meetings.take(3).map(_meetingCard).toList(),
          ),
          const SizedBox(height: 16),
          _sectionHeader('Academic Hubs'),
          const SizedBox(height: 8),
          ..._hubs.map(_hubTile),
          const SizedBox(height: 16),
          _sectionHeader('Direct Conversations'),
          const SizedBox(height: 8),
          ..._conversations.map(_conversationTile),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _overviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDeep, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campus dashboard',
            style: AppTextStyles.label.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Everything in Campuz, backed by live data.',
            style: AppTextStyles.heading.copyWith(
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statChip('Hubs', _hubs.length),
              _statChip('Chats', _conversations.length),
              _statChip('Tasks', _tasks.length),
              _statChip('Meetings', _meetings.length),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: AppTextStyles.label.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summarySection({
    required String title,
    required String subtitle,
    required String emptyTitle,
    required String emptyBody,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            subtitle,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emptyTitle,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emptyBody,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => children[index],
            ),
          ),
      ],
    );
  }

  Widget _recentMessageCard(Map<String, dynamic> conversation) {
    final user = conversation['other_user'] as Map<String, dynamic>? ?? const {};
    final lastMessage = conversation['last_message'] as Map<String, dynamic>? ?? const {};
    final avatar = (user['avatar_url'] as String? ?? '').trim();
    final name = _conversationName(conversation);
    final preview = (lastMessage['content'] as String? ?? 'No messages yet').trim();
    final unreadCount = conversation['unread_count'] as int? ?? 0;
    final timestamp = _formatTime(_parseDate(lastMessage['timestamp']));
    final id = conversation['id'];

    return GestureDetector(
      onTap: id is int
          ? () => context.push('/direct-chat/$id', extra: conversation)
          : null,
      child: SizedBox(
        width: 240,
        height: 132,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceMuted,
                    backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                    child: avatar.isEmpty
                        ? Text(
                            name.characters.first.toUpperCase(),
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.primaryDeep,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  timestamp,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _announcementCard(Map<String, dynamic> broadcast) {
    final title = (broadcast['title'] as String? ?? 'Announcement').trim();
    final content = (broadcast['content'] as String? ?? '').trim();
    final priority = (broadcast['priority'] as String? ?? 'normal').trim();
    final senderName = (broadcast['sender_name'] as String? ?? 'Campuz user').trim();
    final hubId = broadcast['hub'] as int?;
    final hubName = _hubName(hubId);
    return SizedBox(
      width: 250,
      height: 132,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _priorityColor(priority).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: _priorityColor(priority),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hubName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _priorityColor(priority).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      color: _priorityColor(priority),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resourceCard(Map<String, dynamic> resource) {
    final title = (resource['title'] as String? ?? 'Resource').trim();
    final type = (resource['resource_type'] as String? ?? 'other').trim();
    final uploadedBy = (resource['uploaded_by_name'] as String? ?? 'Campuz user').trim();
    final hubId = resource['hub'] as int?;
    final hubName = _hubName(hubId);
    final url = (resource['url'] as String? ?? '').trim();
    return GestureDetector(
      onTap: url.isNotEmpty ? () => _openUrl(url) : null,
      child: SizedBox(
        width: 245,
        height: 132,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _resourceColor(type).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _resourceIcon(type),
                      color: _resourceColor(type),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      type.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (url.isNotEmpty)
                    Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '$hubName - $uploadedBy',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final title = (task['title'] as String? ?? 'Task').trim();
    final course = (task['course_name'] as String? ?? '').trim();
    final status = (task['status'] as String? ?? 'pending').trim();
    final hubId = task['hub'] as int?;
    final hubName = _hubName(hubId);
    final dueDate = _formatTime(_parseDate(task['due_date']));
    return SizedBox(
      width: 245,
      height: 132,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDeep.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: AppColors.primaryDeep,
                    size: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              course.isEmpty ? hubName : '$course - $hubName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                'Due $dueDate',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meetingCard(Map<String, dynamic> meeting) {
    final title = (meeting['title'] as String? ?? 'Meeting').trim();
    final description = (meeting['description'] as String? ?? '').trim();
    final meetingUrl = (meeting['meeting_url'] as String? ?? '').trim();
    final hubId = meeting['hub'] as int?;
    final hubName = _hubName(hubId);
    final scheduledFor = _parseDate(meeting['scheduled_for']);
    final scheduledText = _formatTime(scheduledFor);
    return GestureDetector(
      onTap: meetingUrl.isNotEmpty ? () => _openUrl(meetingUrl) : null,
      child: SizedBox(
        width: 245,
        height: 132,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDeep.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: AppColors.primaryDeep,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  if (meetingUrl.isNotEmpty)
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                description.isEmpty ? hubName : '$description - $hubName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  scheduledText.isEmpty ? hubName : scheduledText,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hubTile(Map<String, dynamic> hub) {
    final name = (hub['name'] as String? ?? 'Academic Hub').trim();
    final description = (hub['description'] as String? ?? '').trim();
    final memberCount = hub['members_count'] as int? ?? 0;
    final id = hub['id'];
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.primary.withValues(alpha: 0.10),
        child: Text(
          initials.isEmpty ? 'H' : initials,
          style: AppTextStyles.title.copyWith(color: AppColors.primaryDeep),
        ),
      ),
      title: Text(
        name,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        description.isEmpty ? '$memberCount members' : description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
      onTap: id != null
          ? () => context.push('/hub/$id', extra: hub)
          : null,
    );
  }

  Widget _conversationTile(Map<String, dynamic> conversation) {
    final user = conversation['other_user'] as Map<String, dynamic>? ?? const {};
    final lastMessage = conversation['last_message'] as Map<String, dynamic>?;
    final avatar = (user['avatar_url'] as String? ?? '').trim();
    final name = _conversationName(conversation);
    final unreadCount = conversation['unread_count'] as int? ?? 0;
    final content =
        (lastMessage?['content'] as String? ?? 'No messages yet').trim();
    final id = conversation['id'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.surfaceMuted,
        backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
        child: avatar.isEmpty
            ? Text(
                name.characters.first.toUpperCase(),
                style: AppTextStyles.title.copyWith(
                  color: AppColors.primaryDeep,
                ),
              )
            : null,
      ),
      title: Text(
        name,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
      trailing: unreadCount > 0
          ? CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.primary,
              child: Text(
                '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            )
          : null,
      onTap: id is int
          ? () async {
              await context.push('/direct-chat/$id', extra: conversation);
              if (mounted) _loadHome();
            }
          : null,
    );
  }
}
