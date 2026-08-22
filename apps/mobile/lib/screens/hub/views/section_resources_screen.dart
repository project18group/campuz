import 'dart:async';

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class SectionResourcesScreen extends StatefulWidget {
  final int hubId;
  final Map<String, dynamic> section;
  final Map<String, dynamic>? hub;

  const SectionResourcesScreen({
    super.key,
    required this.hubId,
    required this.section,
    this.hub,
  });

  @override
  State<SectionResourcesScreen> createState() => _SectionResourcesScreenState();
}

class _SectionResourcesScreenState extends State<SectionResourcesScreen> {
  final _searchController = TextEditingController();
  final List<Map<String, dynamic>> _resources = [];
  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String _filter = 'all';

  String get _sectionTitle =>
      (widget.section['title'] as String? ?? 'Resources').trim();

  bool get _canManageResources => widget.hub?['can_manage_members'] == true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResources({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final resources = await AuthApiService.getResources(
        hubId: widget.hubId,
        query: _searchController.text.trim(),
        type: _filter,
      );
      if (!mounted) return;
      setState(() {
        _resources
          ..clear()
          ..addAll(resources);
        _isLoading = false;
        _error = null;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load resources right now.';
        _isLoading = false;
      });
    }
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadResources(silent: true),
    );
  }

  String _resourceTypeLabel(String type) {
    switch (type) {
      case 'pdf':
        return 'PDF';
      case 'document':
        return 'Document';
      case 'video':
        return 'Video';
      case 'link':
        return 'Link';
      default:
        return 'Other';
    }
  }

  IconData _resourceIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'video':
        return Icons.play_circle_outline_rounded;
      case 'link':
        return Icons.link_rounded;
      case 'document':
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
      case 'document':
        return Colors.indigo;
      default:
        return AppColors.textSecondary;
    }
  }

  DateTime? _parseUploadDate(Map<String, dynamic> resource) {
    final raw = resource['upload_date'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recently';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _uploadedBy(Map<String, dynamic> resource) {
    final uploadedBy = resource['uploaded_by'] as Map<String, dynamic>? ?? const {};
    final profile = uploadedBy['profile'] as Map<String, dynamic>? ?? const {};
    final name = (resource['uploaded_by_name'] as String? ?? '').trim();
    if (name.isNotEmpty) return name;
    final displayName = (profile['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (profile['full_name'] as String? ?? '').trim();
    return fullName.isNotEmpty ? fullName : 'Campuz user';
  }

  Future<void> _openResource(Map<String, dynamic> resource) async {
    String? url = resource['file'] as String?;
    if (url == null || url.trim().isEmpty) {
      url = resource['url'] as String?;
    }
    url = (url ?? '').trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL or file is available for this resource.')),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid resource URL.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open resource.')),
      );
    }
  }

  Future<void> _deleteResource(Map<String, dynamic> resource) async {
    final resourceId = resource['id'];
    final id = resourceId is int ? resourceId : int.tryParse('$resourceId');
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete resource'),
          content: const Text('This will permanently remove the resource from the hub.'),
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

    if (!mounted || confirmed != true || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await AuthApiService.deleteResource(resourceId: id);
      if (!mounted) return;
      setState(() {
        _resources.removeWhere((item) => item['id'] == id);
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource deleted.')),
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
        const SnackBar(content: Text('Unable to delete resource right now.')),
      );
    }
  }

  Future<void> _showUploadSheet() async {
    if (!_canManageResources) return;

    final titleController = TextEditingController();
    final urlController = TextEditingController();
    String resourceType = 'pdf';
    bool sending = false;
    File? selectedFile;

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
              final title = titleController.text.trim();
              final url = urlController.text.trim();
              if (title.isEmpty || (url.isEmpty && selectedFile == null) || sending) return;
              setSheetState(() => sending = true);
              try {
                final created = await AuthApiService.createHubResource(
                  hubId: widget.hubId,
                  title: title,
                  url: url.isEmpty ? null : url,
                  file: selectedFile,
                  resourceType: resourceType,
                );
                if (!mounted) return;
                setState(() {
                  _resources.insert(0, Map<String, dynamic>.from(created));
                });
                if (!mounted || !sheetContext.mounted) return;
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).pop();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resource uploaded successfully.')),
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
                  const SnackBar(content: Text('Unable to upload resource right now.')),
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
                        'Upload resource',
                        style: AppTextStyles.heading.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(labelText: 'URL'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.pickFiles();
                                if (result != null &&
                                    result.files.isNotEmpty &&
                                    result.files.first.path != null) {
                                  setSheetState(() {
                                    selectedFile = File(result.files.first.path!);
                                  });
                                }
                              },
                              icon: const Icon(Icons.attach_file),
                              label: Text(selectedFile != null ? 'File selected' : 'Pick File'),
                            ),
                          ),
                          if (selectedFile != null)
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setSheetState(() => selectedFile = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: resourceType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                          DropdownMenuItem(value: 'document', child: Text('Document')),
                          DropdownMenuItem(value: 'video', child: Text('Video')),
                          DropdownMenuItem(value: 'link', child: Text('Link')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => resourceType = value);
                        },
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
                              : const Text('Save resource'),
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
    urlController.dispose();
  }

  Widget _buildFilterChips() {
    final chips = const [
      ('All', 'all'),
      ('PDFs', 'pdf'),
      ('Docs', 'document'),
      ('Videos', 'video'),
      ('Links', 'link'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => _scheduleSearch(),
            decoration: InputDecoration(
              hintText: 'Search resources',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
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
                      _loadResources();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> resource) {
    final title = (resource['title'] as String? ?? '').trim();
    final type = (resource['resource_type'] as String? ?? 'other').trim().toLowerCase();
    final uploadedBy = _uploadedBy(resource);
    final uploadDate = _formatDate(_parseUploadDate(resource));
    final canManage = resource['can_manage'] == true || _canManageResources;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openResource(resource),
        onLongPress: canManage ? () => _deleteResource(resource) : null,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (canManage)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteResource(resource);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uploaded by $uploadedBy • $uploadDate',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _resourceColor(type).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _resourceTypeLabel(type),
                        style: AppTextStyles.caption.copyWith(
                          color: _resourceColor(type),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                onPressed: _loadResources,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_resources.isEmpty) {
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
                    : 'No ${_resourceTypeLabel(_filter).toLowerCase()} resources found',
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _resources.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildTile(_resources[index]),
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
              'Files & Links',
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadResources,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _canManageResources
          ? FloatingActionButton.extended(
              onPressed: _showUploadSheet,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload'),
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
