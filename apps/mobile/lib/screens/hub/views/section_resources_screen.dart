import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class SectionResourcesScreen extends StatefulWidget {
  final int hubId;
  final Map<String, dynamic> section;

  const SectionResourcesScreen({
    super.key,
    required this.hubId,
    required this.section,
  });

  @override
  State<SectionResourcesScreen> createState() => _SectionResourcesScreenState();
}

class _SectionResourcesScreenState extends State<SectionResourcesScreen> {
  List<Map<String, dynamic>> _resources = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all';

  String get _sectionTitle =>
      (widget.section['title'] as String? ?? 'Resources').trim();

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // TODO: Call API to fetch resources
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _resources = [
          {
            'id': 1,
            'title': 'Lecture Slides - Week 5',
            'resource_type': 'pdf',
            'url': 'https://example.com/slides.pdf',
            'uploaded_by': 'Dr. Mensah',
            'upload_date': DateTime.now().subtract(const Duration(hours: 3)),
          },
          {
            'id': 2,
            'title': 'Course Textbook (Digital)',
            'resource_type': 'pdf',
            'url': 'https://example.com/textbook.pdf',
            'uploaded_by': 'Prof. Asante',
            'upload_date': DateTime.now().subtract(const Duration(days: 7)),
          },
          {
            'id': 3,
            'title': 'Python Tutorial Video',
            'resource_type': 'video',
            'url': 'https://youtube.com/watch?v=xyz',
            'uploaded_by': 'TA: Kofi',
            'upload_date': DateTime.now().subtract(const Duration(days: 2)),
          },
          {
            'id': 4,
            'title': 'Online IDE - Replit',
            'resource_type': 'link',
            'url': 'https://replit.com',
            'uploaded_by': 'Dr. Mensah',
            'upload_date': DateTime.now().subtract(const Duration(days: 14)),
          },
          {
            'id': 5,
            'title': 'Assignment Template',
            'resource_type': 'doc',
            'url': 'https://example.com/template.docx',
            'uploaded_by': 'TA: Ama',
            'upload_date': DateTime.now().subtract(const Duration(days: 5)),
          },
        ];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredResources {
    if (_filter == 'all') return _resources;
    return _resources
        .where((r) => r['resource_type'] == _filter)
        .toList();
  }

  IconData _resourceIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'video':
        return Icons.play_circle_outline;
      case 'link':
        return Icons.link;
      case 'doc':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _resourceColor(String type) {
    switch (type) {
      case 'pdf':
        return Colors.red;
      case 'video':
        return Colors.purple;
      case 'link':
        return Colors.blue;
      case 'doc':
        return Colors.indigo;
      default:
        return AppColors.textSecondary;
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
              'Files & Links',
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
            _buildFilterChip('PDFs', 'pdf'),
            const SizedBox(width: 8),
            _buildFilterChip('Videos', 'video'),
            const SizedBox(width: 8),
            _buildFilterChip('Links', 'link'),
            const SizedBox(width: 8),
            _buildFilterChip('Docs', 'doc'),
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
                onPressed: _loadResources,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredResources;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_outlined,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No resources',
                style: AppTextStyles.heading.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _filter == 'all'
                    ? 'No resources have been uploaded yet'
                    : 'No $_filter resources found',
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
      onRefresh: _loadResources,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildResourceTile(filtered[index]),
      ),
    );
  }

  Widget _buildResourceTile(Map<String, dynamic> resource) {
    final title = resource['title'] as String;
    final type = resource['resource_type'] as String;
    final uploadedBy = resource['uploaded_by'] as String;
    final uploadDate = resource['upload_date'] as DateTime;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening $title...')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _resourceColor(type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _resourceIcon(type),
                  color: _resourceColor(type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uploaded by $uploadedBy • ${_formatDate(uploadDate)}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
