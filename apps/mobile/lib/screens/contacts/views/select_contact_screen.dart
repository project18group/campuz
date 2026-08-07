import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _users = const [];
  bool _isLoading = true;
  bool _isOpening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadUsers(query: value.trim());
    });
  }

  Future<void> _loadUsers({String query = ''}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await AuthApiService.searchUsers(query: query);
      if (mounted) {
        setState(() {
          _users = users;
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to load Campuz contacts.';
        });
      }
    }
  }

  Future<void> _openConversation(Map<String, dynamic> user) async {
    final userId = user['id'];
    if (userId is! int || _isOpening) return;

    setState(() => _isOpening = true);
    try {
      final conversation = await AuthApiService.getOrCreateDirectConversation(
        otherUserId: userId,
      );
      if (!mounted) return;

      final conversationId = conversation['id'];
      if (conversationId is! int) {
        throw const AuthApiException('The conversation could not be opened.');
      }

      context.push('/direct-chat/$conversationId', extra: conversation);
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  String _displayName(Map<String, dynamic> user) {
    final displayName = (user['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (user['full_name'] as String? ?? '').trim();
    return fullName.isEmpty ? 'Campuz user' : fullName;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Conversation', style: AppTextStyles.title),
            Text(
              '${_users.length} Campuz contact${_users.length == 1 ? '' : 's'}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name or phone number',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _loadUsers();
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.surfaceMuted,
                  child: Icon(Icons.groups_outlined),
                ),
                title: Text('New Academic Hub', style: AppTextStyles.label),
                subtitle: Text(
                  'Create a class workspace',
                  style: AppTextStyles.caption,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/create-hub'),
              ),
              const Divider(height: 1),
              Expanded(child: _buildContent(query)),
            ],
          ),
          if (_isOpening)
            const ColoredBox(
              color: Color(0x22000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(String query) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Contacts unavailable',
        message: _error!,
        actionLabel: 'Try Again',
        onAction: () => _loadUsers(query: query),
      );
    }

    if (_users.isEmpty) {
      return _EmptyState(
        icon: query.isEmpty ? Icons.people_outline : Icons.search_off,
        title: query.isEmpty ? 'No Campuz contacts yet' : 'No search results',
        message: query.isEmpty
            ? 'Invite classmates to Campuz to start chatting.'
            : 'Try another name or phone number.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadUsers(query: query),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) {
          final user = _users[index];
          final avatar = (user['avatar_url'] as String? ?? '').trim();
          final phone = (user['phone_number'] as String? ?? '').trim();
          final verified = user['is_verified'] as bool? ?? false;
          final name = _displayName(user);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 5,
            ),
            leading: CircleAvatar(
              radius: 25,
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
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label,
                  ),
                ),
                if (verified) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified,
                    size: 17,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
            subtitle: phone.isEmpty ? null : Text(phone),
            onTap: () => _openConversation(user),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.primaryDeep),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
