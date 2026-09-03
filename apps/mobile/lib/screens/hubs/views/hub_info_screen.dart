import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/hubs/widget/invite_card.dart';
import 'package:mobile/screens/hubs/widget/edit_hub_sheet.dart';

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
      final result = await AuthApiService.getHubMembers(hubId: _hubId);
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
      await AuthApiService.updateHubMembership(
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
                    _confirmAction(
                      title: role == 'admin' ? 'Demote member' : 'Promote member',
                      content: role == 'admin'
                          ? 'Are you sure you want to demote $displayName to a regular member?'
                          : 'Are you sure you want to promote $displayName to an admin? They will have full control over the hub.',
                      actionLabel: role == 'admin' ? 'Demote' : 'Promote',
                      actionColor: AppColors.primaryForeground,
                      onConfirm: () => _runAction(
                        action: role == 'admin' ? 'demote' : 'promote',
                        userId: _memberUserId(member),
                      ),
                    );
                  },
                ),
              if (!isSelf)
                ListTile(
                  leading: Icon(Icons.person_remove_alt_1_outlined, color: AppColors.error),
                  title: Text(
                    'Remove from hub',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmAction(
                      title: 'Remove member',
                      content: 'Are you sure you want to remove $displayName from this hub?',
                      actionLabel: 'Remove',
                      actionColor: AppColors.error,
                      onConfirm: () => _runAction(
                        action: 'remove',
                        userId: _memberUserId(member),
                      ),
                    );
                  },
                ),
              if (isSelf)
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: AppColors.error),
                  title: Text(
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

  void _confirmAction({
    required String title,
    required String content,
    required String actionLabel,
    required Color actionColor,
    required VoidCallback onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onConfirm();
              },
              child: Text(
                actionLabel,
                style: TextStyle(color: actionColor),
              ),
            ),
          ],
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
              child: Text(
                'Leave',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddMembersSheet() async {
    final searchController = TextEditingController();
    final selectedIds = <int>{};
    List<Map<String, dynamic>> results = const [];
    bool loading = true;
    bool submitting = false;
    String? error;
    Timer? debounce;
    bool initialSearchStarted = false;
    bool sheetIsOpen = true;

    Future<void> searchUsers(
      String query,
      void Function(void Function()) setModalState,
    ) async {
      if (!sheetIsOpen || !mounted) return;
      setModalState(() {
        loading = true;
        error = null;
      });

      try {
        final users = await AuthApiService.searchUsers(query: query);
        if (!mounted || !sheetIsOpen) return;
        setModalState(() {
          results = users;
          selectedIds.removeWhere(
            (id) => !users.any((user) {
              final userId = user['id'];
              return userId == id || int.tryParse('$userId') == id;
            }),
          );
          loading = false;
        });
      } on AuthApiException catch (authError) {
        if (!mounted || !sheetIsOpen) return;
        setModalState(() {
          error = authError.message;
          loading = false;
        });
      } catch (_) {
        if (!mounted || !sheetIsOpen) return;
        setModalState(() {
          error = 'Unable to search Campuz users right now.';
          loading = false;
        });
      }
    }

    final sheetFuture = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            if (!initialSearchStarted) {
              initialSearchStarted = true;
              Future.microtask(() => searchUsers('', setModalState));
            }
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Add members',
                      style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Search Campuz users and add them to this hub.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by name or phone number',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        debounce?.cancel();
                        debounce = Timer(
                          const Duration(milliseconds: 300),
                          () {
                            if (!sheetIsOpen || !mounted) return;
                            searchUsers(value.trim(), setModalState);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          error!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No users found.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 380),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 72),
                          itemBuilder: (context, index) {
                            final user = results[index];
                            final id = user['id'];
                            final userId = id is int ? id : int.tryParse('$id');
                            if (userId == null) {
                              return const SizedBox.shrink();
                            }
                            final avatar =
                                (user['avatar_url'] as String? ?? '').trim();
                            final displayName = _userDisplayName(user);
                            final phone =
                                (user['phone_number'] as String? ?? '').trim();
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: selectedIds.contains(userId),
                              onChanged: (value) {
                                setModalState(() {
                                  if (value == true) {
                                    selectedIds.add(userId);
                                  } else {
                                    selectedIds.remove(userId);
                                  }
                                });
                              },
                              secondary: AppAvatar(avatarUrl: avatar, fallbackName: displayName, size: 40),
                              title: Text(displayName),
                              subtitle: Text(phone),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selectedIds.isEmpty || submitting
                            ? null
                            : () async {
                                debounce?.cancel();
                                final selectedUserIds = selectedIds.toList()
                                  ..sort();
                                setModalState(() => submitting = true);
                                try {
                                  await AuthApiService.updateHubMembership(
                                    hubId: _hubId,
                                    action: 'add',
                                    userIds: selectedUserIds,
                                  );
                                  if (!context.mounted) return;
                                  sheetIsOpen = false;
                                  Navigator.pop(sheetContext);
                                  await _loadMembers();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Members added to the hub'),
                                    ),
                                  );
                                } on AuthApiException catch (error) {
                                  if (!mounted || !sheetIsOpen) return;
                                  setModalState(() => submitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.message)),
                                  );
                                } catch (_) {
                                  if (!mounted || !sheetIsOpen) return;
                                  setModalState(() => submitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Unable to add members right now'),
                                    ),
                                  );
                                }
                              },
                        icon: submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(
                          selectedIds.isEmpty
                              ? 'Select users to add'
                              : 'Add ${selectedIds.length} selected',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    sheetFuture.whenComplete(() {
      sheetIsOpen = false;
      debounce?.cancel();
      searchController.dispose();
    });
    await sheetFuture;
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

  String _userDisplayName(Map<String, dynamic> user) {
    final displayName = (user['display_name'] as String? ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final fullName = (user['full_name'] as String? ?? '').trim();
    if (fullName.isNotEmpty) return fullName;
    return 'Campuz user';
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
          color: isAdmin ? AppColors.primaryForeground : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final name = _memberDisplayName(member);
    final user = member['user'] as Map<String, dynamic>? ?? const {};
    final profile = user['profile'] as Map<String, dynamic>? ?? const {};
    final avatar = (profile['avatar_url'] as String? ?? '').trim();
    
    final isSelf = member['is_self'] == true;
    final role = member['role'] as String? ?? 'member';

    return ListTile(
      onTap: _canManageMembers ? () => _showMemberActions(member) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: AppAvatar(avatarUrl: avatar, fallbackName: name, size: 44),
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
              Icon(Icons.error_outline, size: 52, color: AppColors.textSecondary),
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
          _buildSmsBalanceSection(),
          if (_canManageMembers)
            InviteCard(
              hubId: _hubId,
              hubName: _hubName,
            ),
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (_canManageMembers) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUpdating ? null : _showAddMembersSheet,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Add members'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUpdating ? null : _confirmLeaveHub,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Leave hub'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsBalanceSection() {
    if (!_canManageMembers) return const SizedBox.shrink();
    final smsCredits = (_hub ?? widget.hub)?['sms_credits'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sms_outlined, color: AppColors.primaryForeground),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMS Balance',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$smsCredits credits remaining',
                    style: AppTextStyles.title.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryForeground,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final didTopUp = await context.push('/hub/$_hubId/top-up');
                if (didTopUp == true) {
                  _loadMembers();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Top Up'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              AppAvatar(
                avatarUrl: (_hub ?? widget.hub)?['cover_image_url'] as String? ?? '',
                fallbackName: _hubName,
                size: 56,
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
              if (_canManageMembers)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final updated =
                        await showModalBottomSheet<Map<String, dynamic>>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (sheetContext) {
                        return EditHubSheet(
                          hub: _hub ?? widget.hub ?? {},
                          onHubUpdated: (newHub) {
                            if (mounted) {
                              setState(() {
                                _hub = Map<String, dynamic>.from(newHub);
                              });
                            }
                          },
                        );
                      },
                    );
                    if (updated != null && mounted) {
                      setState(() {
                        _hub = Map<String, dynamic>.from(updated);
                      });
                      _loadMembers();
                    }
                  },
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
                  color: AppColors.primaryForeground,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_hub),
        ),
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
