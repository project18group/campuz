import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/hubs/data/mock_shared_media.dart';

/// Sprint 14 — Shared Media screen.
///
/// Displays all media shared inside a hub, split into Images, Documents and
/// Links tabs. Mock data only (see lib/screens/hubs/data/mock_shared_media.dart).
/// Navigated to via MaterialPageRoute; no required params by design.
class SharedMediaScreen extends StatefulWidget {
  const SharedMediaScreen({super.key});

  @override
  State<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

enum _SortOption { dateNewest, dateOldest, nameAZ, sizeLargest }

enum _DateRangeFilter { allTime, last7Days, last30Days }

class _SharedMediaScreenState extends State<SharedMediaScreen> {
  _SortOption _sort = _SortOption.dateNewest;
  _DateRangeFilter _dateFilter = _DateRangeFilter.allTime;

  /// Active doc-type filters on the Documents tab. Empty = show all.
  final Set<String> _docTypeFilters = {};

  static const List<String> _docTypes = ['pdf', 'docx', 'pptx', 'zip'];

  // ---------------------------------------------------------------------
  // Sorting / filtering helpers (operate on copies of the mock lists)
  // ---------------------------------------------------------------------

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

  List<MediaImageItem> get _images {
    final items = mockSharedImages.where((i) => _inDateRange(i.date)).toList();
    switch (_sort) {
      case _SortOption.dateNewest:
        items.sort((a, b) => b.date.compareTo(a.date));
      case _SortOption.dateOldest:
        items.sort((a, b) => a.date.compareTo(b.date));
      case _SortOption.nameAZ:
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SortOption.sizeLargest:
        items.sort((a, b) => b.size.compareTo(a.size));
    }
    return items;
  }

  List<MediaDocumentItem> get _documents {
    final items = mockSharedDocuments
        .where(
          (d) =>
              _inDateRange(d.date) &&
              (_docTypeFilters.isEmpty || _docTypeFilters.contains(d.type)),
        )
        .toList();
    switch (_sort) {
      case _SortOption.dateNewest:
        items.sort((a, b) => b.date.compareTo(a.date));
      case _SortOption.dateOldest:
        items.sort((a, b) => a.date.compareTo(b.date));
      case _SortOption.nameAZ:
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SortOption.sizeLargest:
        items.sort((a, b) => b.size.compareTo(a.size));
    }
    return items;
  }

  List<MediaLinkItem> get _links {
    final items = mockSharedLinks.where((l) => _inDateRange(l.date)).toList();
    switch (_sort) {
      case _SortOption.dateNewest:
        items.sort((a, b) => b.date.compareTo(a.date));
      case _SortOption.dateOldest:
        items.sort((a, b) => a.date.compareTo(b.date));
      case _SortOption.nameAZ:
        items.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _SortOption.sizeLargest:
        // Links have no size; fall back to newest first.
        items.sort((a, b) => b.date.compareTo(a.date));
    }
    return items;
  }

  String _formatDate(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  // ---------------------------------------------------------------------
  // Sort / filter UI
  // ---------------------------------------------------------------------

  void _onSortSelected(_SortOption option) {
    setState(() => _sort = option);
  }

  void _showDateFilterSheet() {
    showModalBottomSheet(
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
                        title: Text(switch (option) {
                          _DateRangeFilter.allTime => 'All time',
                          _DateRangeFilter.last7Days => 'Last 7 days',
                          _DateRangeFilter.last30Days => 'Last 30 days',
                        }, style: AppTextStyles.body),
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textPrimary,
        ),
      );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

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
                      _sortMenuItem(_SortOption.nameAZ, 'Name (A–Z)'),
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
            child: TabBarView(
              children: [_buildImagesTab(), _buildDocumentsTab(), _buildLinksTab()],
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

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Images tab
  // ---------------------------------------------------------------------

  Widget _buildImagesTab() {
    final images = _images;
    if (images.isEmpty) {
      return _emptyState(Icons.image_outlined, 'No images in this range');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return FadeInUp(
          delay: Duration(milliseconds: (index * 50).clamp(0, 500)),
          duration: const Duration(milliseconds: 500),
          child: GestureDetector(
            onTap: () => _openImagePreview(image),
            child: Hero(
              tag: 'shared-media-${image.id}',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: image.gradient,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.image, color: Colors.white70, size: 30),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openImagePreview(MediaImageItem image) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ImagePreviewScreen(image: image)),
    );
  }

  // ---------------------------------------------------------------------
  // Documents tab
  // ---------------------------------------------------------------------

  static IconData _docIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
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
        return const Color(0xFF2563EB);
      case 'pptx':
        return AppColors.warning;
      case 'zip':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildDocumentsTab() {
    final docs = _documents;
    return Column(
      children: [
        // Type filter chips
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
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
              ? _emptyState(
                  Icons.description_outlined,
                  'No documents match the filter',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final color = _docColor(doc.type);
                    return FadeInUp(
                      delay: Duration(milliseconds: (index * 50).clamp(0, 500)),
                      duration: const Duration(milliseconds: 500),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                          onTap: () =>
                              _showSnack('Preview for "${doc.name}" coming soon'),
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
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Icon(
                                    _docIcon(doc.type),
                                    color: color,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.name,
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
                                  icon: const Icon(Icons.download_rounded),
                                  color: AppColors.primary,
                                  onPressed: () => _showSnack('Downloading...'),
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

  // ---------------------------------------------------------------------
  // Links tab
  // ---------------------------------------------------------------------

  Widget _buildLinksTab() {
    final links = _links;
    if (links.isEmpty) {
      return _emptyState(Icons.link_off, 'No links in this range');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: links.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final link = links[index];
        return FadeInUp(
          delay: Duration(milliseconds: (index * 50).clamp(0, 500)),
          duration: const Duration(milliseconds: 500),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
              onTap: () => _showSnack('Opening "${link.url}" coming soon'),
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
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.public,
                        color: AppColors.primary,
                        size: 26,
                      ),
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
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 22,
                      color: AppColors.primary,
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
}

/// Simple self-contained full-screen preview for a mock image.
class _ImagePreviewScreen extends StatelessWidget {
  final MediaImageItem image;

  const _ImagePreviewScreen({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          image.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Hero(
            tag: 'shared-media-${image.id}',
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: image.gradient,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.image, color: Colors.white70, size: 72),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Shared by ${image.sender}',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}