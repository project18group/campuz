import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class HubInfoScreen extends StatefulWidget {
  const HubInfoScreen({super.key, this.hub});

  final Map<String, dynamic>? hub;

  @override
  State<HubInfoScreen> createState() => _HubInfoScreenState();
}

class _HubInfoScreenState extends State<HubInfoScreen> {
  Map<String, dynamic>? _hub;
  List<Map<String, dynamic>> _members = const [];
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _error;

  int get _hubId {
    final value = (_hub ?? widget.hub)?['id'];
    return value is int ? value : int.tryParse('$value') ?? 0;
  }

  String get _hubName =>
      ((_hub ?? widget.hub)?['name'] as String? ?? 'Hub').trim();

  String get _hubDescription =>
      ((_hub ?? widget.hub)?['description'] as String? ?? '').trim();

  int get _memberCount {
    final value = (_hub ?? widget.hub)?['members_count'];
    if (value is int) return value;
    return _members.length;
  }

  bool get _canManageMembers {
    final value = (_hub ?? widget.hub)?['can_manage_members'];
    return value == true;
  }

  List<Map<String, dynamic>> get _admins =>
      _members.where((member) => member['role'] == 'admin').toList();

  @override
  void initState() {
    super.initState();
    _hub = widget.hub;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (_hubId == 0) {
      setState(() {
        _isLoading = false;
        _error = 'This hub cannot be opened right now.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await getHubMembers(hubId: _hubId);
      final hub = result['hub'];
      final members = result['members'];

      if (!mounted) return;

      setState(() {
        if (hub is Map<String, dynamic>) {
          _hub = Map<String, dynamic>.from(hub);
        }
        _members = members is List
            ? members
                .whereType<Map<String, dynamic>>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : const [];
        _isLoading = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load hub members right now.';
      });
    }
  }

  Future<void> _runAction({
    required String action,
    int? userId,
    String? successMessage,
    bool shouldLeaveScreen = false,
  }) async {
    if (action != 'leave' && !_canManageMembers) return;

    setState(() => _isUpdating = true);

    try {
      await updateHubMembership(
        hubId: _hubId,
        action: action,
        userId: userId,
      );

      if (!mounted) return;

      await _loadMembers();

      if (!mounted) return;

      setState(() => _isUpdating = false);

      if (successMessage != null && successMessage.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }

      if (shouldLeaveScreen) {
        context.go('/home');
      }
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update hub membership right now')),
      );
    }
  }

  void _showMemberActions(Map<String, dynamic> member) {
    if (!_canManageMembers) return;

    final isSelf = member['is_self'] == true;
    final role = member['role'] as String? ?? 'member';
    final displayName = _memberDisplayName(member);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Manage $displayName',
                  style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (!isSelf)
                ListTile(
                  leading: Icon(
                    role == 'admin'
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                  title: Text(role == 'admin' ? 'Demote to member' : 'Promote to admin'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _runAction(
                      action: role == 'admin' ? 'demote' : 'promote',
                      userId: _memberUserId(member),
                    );
                  },
                ),
              if (!isSelf)
                ListTile(
                  leading: const Icon(Icons.person_remove_alt_1_outlined, color: AppColors.error),
                  title: const Text(
                    'Remove from hub',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _runAction(
                      action: 'remove',
                      userId: _memberUserId(member),
                    );
                  },
                ),
              if (isSelf)
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: const Text(
                    'Leave hub',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmLeaveHub();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLeaveHub() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave hub'),
          content: const Text(
            'Are you sure you want to leave this hub? You can join again later if you are invited back.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _runAction(
                  action: 'leave',
                  successMessage: 'You left the hub.',
                  shouldLeaveScreen: true,
                );
              },
              child: const Text(
                'Leave',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  int? _memberUserId(Map<String, dynamic> member) {
    final user = member['user'];
    if (user is Map<String, dynamic>) {
      final id = user['id'];
      if (id is int) return id;
      return int.tryParse('$id');
    }
    return null;
  }

  String _memberDisplayName(Map<String, dynamic> member) {
    final user = member['user'] as Map<String, dynamic>? ?? const {};
    final profile = user['profile'] as Map<String, dynamic>? ?? const {};
    final displayName = (profile['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (profile['full_name'] as String? ?? '').trim();
    if (fullName.isNotEmpty) return fullName;
    return 'Campuz user';
  }

  String _memberUsername(Map<String, dynamic> member) {
    final user = member['user'] as Map<String, dynamic>? ?? const {};
    final profile = user['profile'] as Map<String, dynamic>? ?? const {};
    return (profile['phone_number'] as String? ?? '').trim();
  }

  Widget _buildRoleChip(String role) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'Member',
        style: AppTextStyles.caption.copyWith(
          color: isAdmin ? AppColors.primaryDeep : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final name = _memberDisplayName(member);
    final isSelf = member['is_self'] == true;
    final role = member['role'] as String? ?? 'member';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return ListTile(
      onTap: _canManageMembers ? () => _showMemberActions(member) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary.withValues(alpha: 0.10),
        child: Text(
          initials.isEmpty ? 'C' : initials,
          style: AppTextStyles.label.copyWith(
            color: AppColors.primaryDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (isSelf) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'you',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        _memberUsername(member),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
      trailing: _buildRoleChip(role),
    );
  }

  Widget _buildAdminsSection() {
    if (!_canManageMembers) return const SizedBox.shrink();
    if (_admins.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admins',
            style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _admins.map((member) {
              return Chip(
                label: Text(_memberDisplayName(member)),
                avatar: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                side: BorderSide(color: AppColors.border),
                backgroundColor: AppColors.surface,
              );
            }).toList(),
          ),
        ],
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
              const Icon(Icons.error_outline, size: 52, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text('Unable to open hub', style: AppTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadMembers,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildHeader(),
          _buildAdminsSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Members ($_memberCount)',
                  style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_canManageMembers)
                  Text(
                    'Tap a member to manage',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: _members.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No members found.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        )
                    : Column(
                        children: List.generate(_members.length, (index) {
                          final member = _members[index];
                          return Column(
                            children: [
                              _buildMemberTile(member),
                              if (index != _members.length - 1)
                                const Divider(height: 1, indent: 54),
                            ],
                          );
                        }),
                      ),
              ),
            ),
          ),
          if (_canManageMembers) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                onPressed: _isUpdating ? null : _confirmLeaveHub,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Leave hub'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final initials = _hubName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  initials.isEmpty ? 'H' : initials,
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
            const SizedBox(height: 14),
            Text(
              _hubDescription,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
          ],
          if (_canManageMembers) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'You can manage members in this hub',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hubId == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hub Info')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.group_outlined, size: 56),
                const SizedBox(height: 12),
                Text('No hub selected', style: AppTextStyles.heading),
                const SizedBox(height: 8),
                Text(
                  'Open this page from a hub so we can load its members.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hub Info'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadMembers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }
}
