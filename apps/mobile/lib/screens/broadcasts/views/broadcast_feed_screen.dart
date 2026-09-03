import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class BroadcastFeedScreen extends StatefulWidget {
  const BroadcastFeedScreen({super.key});

  @override
  State<BroadcastFeedScreen> createState() => _BroadcastFeedScreenState();
}

class _BroadcastFeedScreenState extends State<BroadcastFeedScreen> {
  List<Map<String, dynamic>> _broadcasts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBroadcasts();
  }

  Future<void> _loadBroadcasts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final broadcasts = await AuthApiService.getBroadcasts();
      if (!mounted) return;
      setState(() {
        _broadcasts = broadcasts;
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
        _error = 'Unable to load broadcasts right now.';
        _isLoading = false;
      });
    }
  }

  String _senderName(Map<String, dynamic> broadcast) {
    final sender = broadcast['sender'] as Map<String, dynamic>? ?? const {};
    final profile = sender['profile'] as Map<String, dynamic>? ?? const {};
    final senderName = (broadcast['sender_name'] as String? ?? '').trim();
    if (senderName.isNotEmpty) return senderName;
    final displayName = (profile['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (profile['full_name'] as String? ?? '').trim();
    return fullName.isNotEmpty ? fullName : 'Campuz user';
  }

  DateTime? _parseTimestamp(Map<String, dynamic> broadcast) {
    final raw = broadcast['timestamp'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _formatTimestamp(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${time.day}/${time.month}/${time.year}';
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

  Widget _buildCard(Map<String, dynamic> broadcast) {
    final title = (broadcast['title'] as String? ?? '').trim();
    final content = (broadcast['content'] as String? ?? '').trim();
    final priority = (broadcast['priority'] as String? ?? 'normal').trim();
    final timestamp = _formatTimestamp(_parseTimestamp(broadcast));
    final senderName = _senderName(broadcast);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: priority == 'high'
              ? _priorityColor(priority).withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
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
                    priority == 'high' ? Icons.priority_high : Icons.campaign_outlined,
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
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 18,
                          color: AppColors.primaryForeground,
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
                if (priority == 'high')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryForeground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'URGENT',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(content, style: AppTextStyles.body),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  timestamp,
                  style: AppTextStyles.caption.copyWith(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: const Text('Campus Broadcasts'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadBroadcasts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        color: AppColors.background,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 52),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadBroadcasts,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBroadcasts,
                    child: _broadcasts.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.65,
                                child: Center(
                                  child: Text(
                                    'No broadcasts available',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _broadcasts.length,
                            itemBuilder: (context, index) =>
                                _buildCard(_broadcasts[index]),
                          ),
                  ),
      ),
    );
  }
}