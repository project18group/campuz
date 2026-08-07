import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/home/widgets/empty_home_state.dart';
import 'package:mobile/shared/widgets/app_fab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _hubs = const [];
  List<Map<String, dynamic>> _conversations = const [];
  bool _isLoading = true;
  String? _error;

  bool get _isEmpty => _hubs.isEmpty && _conversations.isEmpty;

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
      ]);
      if (mounted) {
        setState(() {
          _hubs = results[0];
          _conversations = results[1];
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

    final itemCount =
        (_hubs.isEmpty ? 0 : _hubs.length + 1) +
        (_conversations.isEmpty ? 0 : _conversations.length + 1);

    return RefreshIndicator(
      onRefresh: _loadHome,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) {
          var cursor = index;
          if (_hubs.isNotEmpty) {
            if (cursor == 0) {
              return _sectionHeader('Academic Hubs');
            }
            cursor -= 1;
            if (cursor < _hubs.length) {
              return _hubTile(_hubs[cursor]);
            }
            cursor -= _hubs.length;
          }

          if (_conversations.isNotEmpty) {
            if (cursor == 0) {
              return _sectionHeader('Direct Chats');
            }
            cursor -= 1;
            if (cursor < _conversations.length) {
              return _conversationTile(_conversations[cursor]);
            }
          }

          return const SizedBox.shrink();
        },
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

  Widget _hubTile(Map<String, dynamic> hub) {
    final name = (hub['name'] as String? ?? 'Academic Hub').trim();
    final description = (hub['description'] as String? ?? '').trim();
    final memberCount = hub['members_count'] as int? ?? 0;
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
      onTap: () => context.push('/hub-chat'),
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
