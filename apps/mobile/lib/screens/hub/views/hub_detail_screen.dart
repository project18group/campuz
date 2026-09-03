import 'package:mobile/shared/widgets/app_avatar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/screens/hub/views/section_general_screen.dart';
import 'package:mobile/screens/hub/views/section_announcements_screen.dart';
import 'package:mobile/screens/hub/views/section_meetings_screen.dart';
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

  Map<String, dynamic>? _hub;

  Map<String, dynamic> get currentHub => _hub ?? widget.hub;

  String get _hubName => (currentHub['name'] as String? ?? 'Hub').trim();

  String get _hubDescription =>
      (currentHub['description'] as String? ?? '').trim();

  int get _memberCount => currentHub['members_count'] as int? ?? 0;

  String get _coverImageUrl =>
      (currentHub['cover_image_url'] as String? ?? '').trim();

  @override
  void initState() {
    super.initState();
    _hub = widget.hub;
    _loadHub();
  }

  Future<void> _loadHub() async {
    final id = widget.hub['id'];
    final hubId = id is int ? id : int.tryParse('$id') ?? 0;
    if (hubId == 0) return;
    try {
      final res = await AuthApiService.getHubMembers(hubId: hubId);
      final hub = res['hub'];
      if (hub is Map<String, dynamic> && mounted) {
        setState(() {
          _hub = Map<String, dynamic>.from(hub);
        });
      }
    } catch (_) {}
  }

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

  bool get _isAdmin {
    final members = currentHub['members'] as List<dynamic>? ?? [];
    for (final m in members) {
      if (m is Map && m['is_self'] == true && m['role'] == 'admin') {
        return true;
      }
    }
    return false;
  }

  void _showCreateSectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateSectionSheet(
        hubId: currentHub['id'] as int,
        onCreated: (newSection) {
          setState(() {
            final sections = List<Map<String, dynamic>>.from(currentHub['sections'] ?? []);
            sections.add(newSection);
            currentHub['sections'] = sections;
          });
        },
      ),
    );
  }

  Future<void> _openChat() async {
    final updated = await context.push('/hub-chat', extra: currentHub);
    if (updated is Map<String, dynamic> && mounted) {
      setState(() => _hub = Map<String, dynamic>.from(updated));
    } else {
      _loadHub();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(currentHub),
        ),
        title: Text(_hubName),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: _openChat,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showCreateSectionSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add Section'),
            )
          : null,
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
              AppAvatar(avatarUrl: _coverImageUrl, fallbackName: _hubName, size: 64),
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
                  color: AppColors.primaryForeground,
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
        screen = SectionResourcesScreen(
          hubId: hubId,
          section: section,
          hub: widget.hub,
        );
        break;
      case 'tasks':
        screen = SectionTasksScreen(
          hubId: hubId,
          section: section,
          hub: widget.hub,
        );
        break;
      case 'meetings':
        screen = SectionMeetingsScreen(
          hubId: hubId,
          section: section,
          hub: widget.hub,
        );
        break;
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

class _CreateSectionSheet extends StatefulWidget {
  final int hubId;
  final ValueChanged<Map<String, dynamic>> onCreated;

  const _CreateSectionSheet({required this.hubId, required this.onCreated});

  @override
  State<_CreateSectionSheet> createState() => _CreateSectionSheetState();
}

class _CreateSectionSheetState extends State<_CreateSectionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _sectionType = 'general';
  bool _isLoading = false;

  final _sectionTypes = [
    {'value': 'general', 'label': 'General Chat', 'icon': Icons.chat_bubble_outline},
    {'value': 'announcements', 'label': 'Announcements', 'icon': Icons.campaign_outlined},
    {'value': 'resources', 'label': 'Resources', 'icon': Icons.folder_outlined},
    {'value': 'meetings', 'label': 'Live Sessions', 'icon': Icons.video_call_outlined},
    {'value': 'tasks', 'label': 'Tasks', 'icon': Icons.task_alt_outlined},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final newSection = await AuthApiService.createHubSection(
        hubId: widget.hubId,
        title: _titleController.text.trim(),
        sectionType: _sectionType,
        description: _descController.text.trim(),
      );
      if (mounted) {
        widget.onCreated(newSection);
        Navigator.pop(context);
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create Section',
                  style: AppTextStyles.heading.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Section Title',
                    hintText: 'e.g., General Discussion',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _sectionType,
                  decoration: const InputDecoration(
                    labelText: 'Section Type',
                  ),
                  items: _sectionTypes.map((type) {
                    return DropdownMenuItem(
                      value: type['value'] as String,
                      child: Row(
                        children: [
                          Icon(type['icon'] as IconData, size: 20),
                          const SizedBox(width: 12),
                          Text(type['label'] as String),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _sectionType = val);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Briefly describe this section...',
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
