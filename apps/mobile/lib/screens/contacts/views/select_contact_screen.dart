import 'dart:async';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:mobile/shared/widgets/app_avatar.dart';
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

  List<Map<String, dynamic>> _allTekchatUsers = [];
  List<Contact> _allUnmatchedContacts = [];

  List<Map<String, dynamic>> _filteredTekchatUsers = [];
  List<Contact> _filteredUnmatchedContacts = [];

  bool _isLoading = true;
  bool _isOpening = false;
  bool _permissionDenied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContactsAndSync();
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
      _filterLocally(value.trim());
    });
  }

  String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<void> _loadContactsAndSync() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _permissionDenied = false;
    });

    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _isLoading = false;
          });
        }
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);

      List<String> phoneNumbers = [];
      for (var c in contacts) {
        if (c.phones.isNotEmpty) {
          phoneNumbers.add(c.phones.first.number);
        }
      }

      final matchedUsers = await AuthApiService.syncContacts(
        phoneNumbers: phoneNumbers,
      );

      final matchedPhones = matchedUsers
          .map((u) {
            final p = (u['phone_number'] as String? ?? '');
            return _cleanPhone(p);
          })
          .where((p) => p.isNotEmpty)
          .toSet();

      List<Contact> unmatched = [];
      for (var c in contacts) {
        if (c.phones.isNotEmpty) {
          final p = _cleanPhone(c.phones.first.number);
          if (p.isNotEmpty && !matchedPhones.contains(p)) {
            unmatched.add(c);
          }
        }
      }

      if (mounted) {
        setState(() {
          _allTekchatUsers = matchedUsers;
          _allUnmatchedContacts = unmatched;
          _filteredTekchatUsers = _allTekchatUsers;
          _filteredUnmatchedContacts = _allUnmatchedContacts;
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
          _error = 'Unable to sync contacts.';
        });
      }
    }
  }

  void _filterLocally(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredTekchatUsers = _allTekchatUsers;
        _filteredUnmatchedContacts = _allUnmatchedContacts;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredTekchatUsers = _allTekchatUsers.where((user) {
        final name = _displayName(user).toLowerCase();
        final phone = (user['phone_number'] as String? ?? '').toLowerCase();
        return name.contains(lowerQuery) || phone.contains(lowerQuery);
      }).toList();

      _filteredUnmatchedContacts = _allUnmatchedContacts.where((contact) {
        final name = (contact.displayName ?? '').toLowerCase();
        final phone = contact.phones.isNotEmpty
            ? contact.phones.first.number.toLowerCase()
            : '';
        return name.contains(lowerQuery) || phone.contains(lowerQuery);
      }).toList();
    });
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

  void _inviteContact(Contact contact) {
    // In a real app, this would open SMS with a prefilled message.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite sent to ${contact.displayName}')),
    );
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
              '${_allTekchatUsers.length + _allUnmatchedContacts.length} Contacts',
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
                              _filterLocally('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
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
              Expanded(child: _buildContent()),
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionDenied) {
      return _EmptyState(
        icon: Icons.perm_contact_calendar_outlined,
        title: 'Contacts Access Denied',
        message: 'TekChat needs access to your contacts to find your friends.',
        actionLabel: 'Allow Access',
        onAction: _loadContactsAndSync,
      );
    }

    if (_error != null) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Contacts unavailable',
        message: _error!,
        actionLabel: 'Try Again',
        onAction: _loadContactsAndSync,
      );
    }

    if (_filteredTekchatUsers.isEmpty && _filteredUnmatchedContacts.isEmpty) {
      return _EmptyState(
        icon: _searchController.text.isEmpty
            ? Icons.people_outline
            : Icons.search_off,
        title: _searchController.text.isEmpty
            ? 'No contacts found'
            : 'No search results',
        message: _searchController.text.isEmpty
            ? 'Add some contacts to your phone to get started.'
            : 'Try another name or phone number.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContactsAndSync,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (_filteredTekchatUsers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Contacts on TekChat',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
            ),
            ..._filteredTekchatUsers.map((user) {
              final avatar = (user['avatar_url'] as String? ?? '').trim();
              final phone = (user['phone_number'] as String? ?? '').trim();
              final verified = user['is_verified'] as bool? ?? false;
              final name = _displayName(user);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                leading: AppAvatar(
                  avatarUrl: avatar,
                  fallbackName: name,
                  size: 50,
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
                      Icon(Icons.verified, size: 17, color: AppColors.primary),
                    ],
                  ],
                ),
                subtitle: phone.isEmpty ? null : Text(phone),
                onTap: () => _openConversation(user),
              );
            }),
          ],
          if (_filteredTekchatUsers.isNotEmpty &&
              _filteredUnmatchedContacts.isNotEmpty)
            const Divider(height: 24, thickness: 1),

          if (_filteredUnmatchedContacts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Invite to TekChat',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ..._filteredUnmatchedContacts.map((contact) {
              final name = contact.displayName;
              final phone = contact.phones.isNotEmpty
                  ? contact.phones.first.number
                  : '';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceMuted,
                  radius: 25,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(name!, style: AppTextStyles.label),
                subtitle: phone.isEmpty ? null : Text(phone),
                trailing: TextButton(
                  onPressed: () => _inviteContact(contact),
                  child: const Text('INVITE'),
                ),
              );
            }),
          ],
        ],
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
