import 'dart:ui';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class SharedMediaScreen extends StatefulWidget {
  final int hubId;

  const SharedMediaScreen({super.key, required this.hubId});

  @override
  State<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

enum _SortOption { dateNewest, dateOldest, nameAZ, sizeLargest }

enum _DateRangeFilter { allTime, last7Days, last30Days }

class _SharedMediaItem {
  final String id;
  final String title;
  final String sender;
  final DateTime date;
  final int sizeBytes;
  final String type;
  final String url;
  final List<Color> gradient;

  const _SharedMediaItem({
    required this.id,
    required this.title,
    required this.sender,
    required this.date,
    required this.sizeBytes,
    required this.type,
    required this.url,
    required this.gradient,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _SharedMediaScreenState extends State<SharedMediaScreen> {
  _SortOption _sort = _SortOption.dateNewest;
  _DateRangeFilter _dateFilter = _DateRangeFilter.allTime;
  final Set<String> _docTypeFilters = {};
  static const List<String> _docTypes = ['pdf', 'docx', 'pptx', 'zip'];

  bool _isLoading = true;
  String? _error;
  List<_SharedMediaItem> _allImages = [];
  List<_SharedMediaItem> _allDocs = [];
  List<_SharedMediaItem> _allLinks = [];

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await AuthApiService.getResources(hubId: widget.hubId);
      final images = <_SharedMediaItem>[];
      final docs = <_SharedMediaItem>[];
      final links = <_SharedMediaItem>[];

      for (final item in items) {
        final title = (item['title'] as String? ?? 'Untitled').trim();
        final uploadedBy = (item['uploaded_by_name'] as String? ?? 'Campuz user').trim();
        final url = (item['file'] as String? ?? item['url'] as String? ?? '').trim();
        final type = _inferType(
          (item['resource_type'] as String? ?? '').trim().toLowerCase(),
          url,
        );
        final date = DateTime.tryParse((item['upload_date'] as String? ?? '').trim()) ?? DateTime.now();
        final size = (item['size_bytes'] as num?)?.toInt() ?? 0;
        final mediaItem = _SharedMediaItem(
          id: item['id'].toString(),
          title: title,
          sender: uploadedBy.isEmpty ? 'Campuz user' : uploadedBy,
          date: date,
          sizeBytes: size,
          type: type,
          url: url,
          gradient: _gradientForType(type),
        );

        if (_isImage(type)) {
          images.add(mediaItem);
        } else if (_isDocument(type)) {
          docs.add(mediaItem);
        } else if (_isLink(type)) {
          links.add(mediaItem);
        }
      }

      if (!mounted) return;
      setState(() {
        _allImages = images;
        _allDocs = docs;
        _allLinks = links;
        _isLoading = false;
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
        _error = 'Failed to load resources';
        _isLoading = false;
      });
    }
  }

  static bool _isImage(String type) => type == 'image';

  static bool _isDocument(String type) =>
      type == 'pdf' || type == 'document' || type == 'docx' || type == 'pptx' || type == 'zip';

  static bool _isLink(String type) => type == 'link';

  static String _inferType(String resourceType, String url) {
    final lower = url.toLowerCase();
    if (resourceType == 'link' ||
        (lower.startsWith('http://') && !lower.contains(RegExp(r'\.(jpg|jpeg|png|gif|webp|bmp|heic|heif|pdf|docx?|pptx?|zip|rar|7z)$')))) {
      return 'link';
    }
    if (resourceType == 'image' ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif')) {
      return 'image';
    }
    if (resourceType == 'pdf' || lower.endsWith('.pdf')) return 'pdf';
    if (resourceType == 'docx' ||
        resourceType == 'document' ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx')) {
      return 'docx';
    }
    if (resourceType == 'pptx' || lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return 'pptx';
    }
    if (resourceType == 'zip' ||
        lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z')) {
      return 'zip';
    }
    return resourceType.isEmpty ? 'document' : resourceType;
  }

  static List<Color> _gradientForType(String type) {
    switch (type) {
      case 'image':
        return const [Color(0xFFA61D37), Color(0xFFD94F70)];
      case 'pdf':
        return const [Color(0xFF2563EB), Color(0xFF60A5FA)];
      case 'docx':
      case 'document':
        return const [Color(0xFF059669), Color(0xFF34D399)];
      case 'pptx':
        return const [Color(0xFFF59E0B), Color(0xFFFBBF24)];
      case 'zip':
        return const [Color(0xFF7C3AED), Color(0xFFA78BFA)];
      case 'link':
        return const [Color(0xFF0891B2), Color(0xFF67E8F9)];
      default:
        return const [Color(0xFF4B5563), Color(0xFF9CA3AF)];
    }
  }

  bool _inDateRange(DateTime date) {
    switch (_dateFilter) {
      case _DateRangeFilter.allTime:
        return true;
      case _DateRangeFilter.last7Days:
        return DateTime.now().difference(date).inDays <= 7;
      case _DateRangeFilter.last30Days:
        return DateTime.now().difference(date).inDays <= 30;
    }
  }

  List<_SharedMediaItem> get _images {
    final items = _allImages.where((item) => _inDateRange(item.date)).toList();
    switch (_sort) {
      case _SortOption.dateNewest:
        items.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _SortOption.dateOldest:
        items.sort((a, b) => a.date.compareTo(b.date));
        break;
      case _SortOption.nameAZ:
        items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _SortOption.sizeLargest:
        items.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
    }
    return items;
  }

  List<_SharedMediaItem> get _documents {
    final items = _allDocs
        .where(
          (item) =>
              _inDateRange(item.date) &&
              (_docTypeFilters.isEmpty || _docTypeFilters.contains(item.type)),
        )
        .toList();
    switch (_sort) {
      case _SortOption.dateNewest:
        items.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _SortOption.dateOldest:
        items.sort((a, b) => a.date.compareTo(b.date));
        break;
      case _SortOption.nameAZ:
        items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _SortOption.sizeLargest:
        items.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
    }
    return items;
  }

  List<_SharedMediaItem> get _links {
    final items = _allLinks.where((item) => _inDateRange(item.date)).toList();
    switch (_sort) {
      case _SortOption.dateNewest:
        items.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _SortOption.dateOldest:
        items.sort((a, b) => a.date.compareTo(b.date));
        break;
      case _SortOption.nameAZ:
        items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _SortOption.sizeLargest:
        items.sort((a, b) => b.date.compareTo(a.date));
        break;
    }
    return items;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _onSortSelected(_SortOption option) {
    setState(() => _sort = option);
  }

  void _showDateFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('Filter by date', style: AppTextStyles.title),
              ),
              RadioGroup<_DateRangeFilter>(
                groupValue: _dateFilter,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _dateFilter = value);
                  }
                  Navigator.of(sheetContext).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in _DateRangeFilter.values)
                      RadioListTile<_DateRangeFilter>(
                        value: option,
                        activeColor: AppColors.primary,
                        title: Text(
                          switch (option) {
                            _DateRangeFilter.allTime => 'All time',
                            _DateRangeFilter.last7Days => 'Last 7 days',
                            _DateRangeFilter.last30Days => 'Last 30 days',
                          },
                          style: AppTextStyles.body,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openUrl(String url) async {
    if (url.trim().isEmpty) {
      _showSnack('No file is available for this item.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('Invalid link.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showSnack('Could not open this item.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.background),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textPrimary,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 48),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AppBar(
                backgroundColor: AppColors.surface.withValues(alpha: 0.6),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                iconTheme: IconThemeData(color: AppColors.textPrimary),
                title: Text(
                  'Class Resources',
                  style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Filter by date',
                    icon: Icon(
                      _dateFilter == _DateRangeFilter.allTime
                          ? Icons.filter_alt_outlined
                          : Icons.filter_alt,
                      color: _dateFilter == _DateRangeFilter.allTime
                          ? AppColors.textPrimary
                          : AppColors.primary,
                    ),
                    onPressed: _showDateFilterSheet,
                  ),
                  PopupMenuButton<_SortOption>(
                    tooltip: 'Sort',
                    icon: Icon(Icons.sort, color: AppColors.textPrimary),
                    color: AppColors.surface,
                    onSelected: _onSortSelected,
                    itemBuilder: (context) => [
                      _sortMenuItem(_SortOption.dateNewest, 'Date (newest first)'),
                      _sortMenuItem(_SortOption.dateOldest, 'Date (oldest first)'),
                      _sortMenuItem(_SortOption.nameAZ, 'Name (A-Z)'),
                      _sortMenuItem(_SortOption.sizeLargest, 'Size (largest first)'),
                    ],
                  ),
                ],
                bottom: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: AppTextStyles.label.copyWith(fontSize: 14),
                  unselectedLabelStyle: AppTextStyles.body,
                  tabs: const [
                    Tab(text: 'Images'),
                    Tab(text: 'Documents'),
                    Tab(text: 'Links'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.05),
                AppColors.background,
              ],
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : TabBarView(
                        children: [
                          _buildImagesTab(),
                          _buildDocumentsTab(),
                          _buildLinksTab(),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_SortOption> _sortMenuItem(_SortOption option, String label) {
    final selected = _sort == option;
    return PopupMenuItem<_SortOption>(
      value: option,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 18,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: selected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
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

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesTab() {
    final images = _images;
    if (images.isEmpty) {
      return _emptyState(Icons.image_outlined, 'No images in this hub yet');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return FadeInUp(
          delay: Duration(milliseconds: (index * 50).clamp(0, 500)),
          duration: const Duration(milliseconds: 450),
          child: GestureDetector(
            onTap: () => _openImagePreview(image),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: image.url.isNotEmpty
                          ? Image.network(
                              image.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _gradientPreview(image),
                            )
                          : _gradientPreview(image),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            image.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Shared by ${image.sender}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _gradientPreview(_SharedMediaItem item) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.gradient,
        ),
      ),
      child: const Center(
        child: Icon(Icons.image, color: Colors.white70, size: 64),
      ),
    );
  }

  void _openImagePreview(_SharedMediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ImagePreviewScreen(item: item)),
    );
  }

  Widget _buildDocumentsTab() {
    final docs = _documents;
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: _docTypes.map((type) {
              final selected = _docTypeFilters.contains(type);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    type.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary,
                  side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _docTypeFilters.add(type);
                      } else {
                        _docTypeFilters.remove(type);
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: docs.isEmpty
              ? _emptyState(Icons.description_outlined, 'No documents match the filter')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final color = _docColor(doc.type);
                    return FadeInUp(
                      delay: Duration(milliseconds: (index * 50).clamp(0, 500)),
                      duration: const Duration(milliseconds: 450),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openUrl(doc.url),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        color.withValues(alpha: 0.2),
                                        color.withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: color.withValues(alpha: 0.1)),
                                  ),
                                  child: Icon(_docIcon(doc.type), color: color, size: 26),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.sd_storage_outlined, size: 14, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            doc.formattedSize,
                                            style: AppTextStyles.caption.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDate(doc.date),
                                            style: AppTextStyles.caption.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  color: AppColors.primary,
                                  onPressed: () => _openUrl(doc.url),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLinksTab() {
    final links = _links;
    if (links.isEmpty) {
      return _emptyState(Icons.link_off, 'No links in this hub yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: links.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final link = links[index];
        return FadeInUp(
          delay: Duration(milliseconds: (index * 50).clamp(0, 500)),
          duration: const Duration(milliseconds: 450),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openUrl(link.url),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.primary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      child: Icon(Icons.public, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            link.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(link.date),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  link.sender,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new_rounded, size: 22, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static IconData _docIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'document':
        return Icons.description;
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  static Color _docColor(String type) {
    switch (type) {
      case 'pdf':
        return AppColors.error;
      case 'docx':
      case 'document':
        return const Color(0xFF2563EB);
      case 'pptx':
        return AppColors.warning;
      case 'zip':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.textSecondary;
    }
  }
}

class _ImagePreviewScreen extends StatelessWidget {
  final _SharedMediaItem item;

  const _ImagePreviewScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: item.url.isNotEmpty
              ? Image.network(
                  item.url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _previewFallback(item),
                )
              : _previewFallback(item),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Shared by ${item.sender}',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _previewFallback(_SharedMediaItem item) {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.gradient,
        ),
      ),
      child: const AspectRatio(
        aspectRatio: 1,
        child: Center(
          child: Icon(Icons.image, color: Colors.white70, size: 72),
        ),
      ),
    );
  }
}
