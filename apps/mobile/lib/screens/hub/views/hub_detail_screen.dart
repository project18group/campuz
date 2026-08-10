import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/hub/views/section_general_screen.dart';
import 'package:mobile/screens/hub/views/section_announcements_screen.dart';
import 'package:mobile/screens/hub/views/section_resources_screen.dart';
import 'package:mobile/screens/hub/views/section_tasks_screen.dart';

class HubDetailScreen extends StatefulWidget {
  final Map<String, dynamic> hub;

  const HubDetailScreen({super.key, required this.hub});

  @override
  State<HubDetailScreen> createState() => _HubDetailScreenState();
}

class _HubDetailScreenState extends State<HubDetailScreen> {
  List<Map<String, dynamic>> get _sections {
    final sections = widget.hub['sections'] as List<dynamic>? ?? [];
    return sections
        .cast<Map<String, dynamic>>()
        .where((s) => s['is_enabled'] == true)
        .toList()
      ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
  }

  String get _hubName => (widget.hub['name'] as String? ?? 'Hub').trim();

  String get _hubDescription =>
      (widget.hub['description'] as String? ?? '').trim();

  int get _memberCount => widget.hub['members_count'] as int? ?? 0;

  IconData _sectionIcon(String sectionType) {
    switch (sectionType) {
      case 'general':
        return Icons.chat_bubble_outline;
      case 'announcements':
        return Icons.campaign_outlined;
      case 'resources':
        return Icons.folder_outlined;
      case 'meetings':
        return Icons.video_call_outlined;
      case 'tasks':
        return Icons.task_alt_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_hubName),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/hub-chat', extra: widget.hub),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        if (_sections.isEmpty) ...[
          SliverFillRemaining(child: _buildEmptyState()),
        ] else ...[
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildSectionCard(_sections[index]),
                childCount: _sections.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  _hubName.characters.first.toUpperCase(),
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.primaryDeep,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hubName,
                      style: AppTextStyles.heading.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_memberCount members',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hubDescription.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _hubDescription,
              style: AppTextStyles.body,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section) {
    final title = (section['title'] as String? ?? 'Section').trim();
    final sectionType = section['section_type'] as String? ?? 'general';
    final description = (section['description'] as String? ?? '').trim();

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AppColors.border,
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          _navigateToSection(section);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  _sectionIcon(sectionType),
                  color: AppColors.primaryDeep,
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Sections',
              style: AppTextStyles.heading.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'This hub has no active sections yet.',
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

  void _navigateToSection(Map<String, dynamic> section) {
    final sectionType = section['section_type'] as String? ?? 'general';
    final hubId = widget.hub['id'] as int;

    Widget screen;
    switch (sectionType) {
      case 'general':
        screen = SectionGeneralScreen(
          hubId: hubId,
          section: section,
          hub: widget.hub,
        );
        break;
      case 'announcements':
        screen = SectionAnnouncementsScreen(
          hubId: hubId,
          section: section,
          hub: widget.hub,
        );
        break;
      case 'resources':
        screen = SectionResourcesScreen(hubId: hubId, section: section);
        break;
      case 'tasks':
        screen = SectionTasksScreen(hubId: hubId, section: section);
        break;
      case 'meetings':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meetings section coming soon...')),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unknown section type: $sectionType')),
        );
        return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}
