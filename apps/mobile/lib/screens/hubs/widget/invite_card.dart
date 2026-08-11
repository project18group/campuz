import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InviteCard extends StatefulWidget {
  const InviteCard({
    super.key,
    required this.hubId,
    required this.hubName,
  });

  final int hubId;
  final String hubName;

  @override
  State<InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<InviteCard> {
  Map<String, dynamic>? _invite;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite({bool refresh = false}) async {
    if (refresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = refresh
          ? await AuthApiService.createHubInvite(hubId: widget.hubId)
          : await AuthApiService.getHubInvite(hubId: widget.hubId);
      if (!mounted) return;
      setState(() {
        _invite = result['invite'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(result['invite'] as Map)
            : null;
        _isLoading = false;
        _isRefreshing = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load invite right now.';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  String _inviteUrl() {
    final invite = _invite ?? const {};
    final url = (invite['invite_url'] as String? ?? '').trim();
    if (url.isNotEmpty) return url;
    return 'https://campuz.app/join';
  }

  String _inviteCode() {
    final invite = _invite ?? const {};
    return (invite['code'] as String? ?? '').trim();
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteUrl()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invite link copied')));
  }

  void _showQrDialog() {
    final inviteUrl = _inviteUrl();
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.hubName, style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text('Scan to join', style: AppTextStyles.caption),
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: QrImageView(data: inviteUrl),
                ),
                const SizedBox(height: 16),
                Text(_inviteCode().isEmpty ? inviteUrl : _inviteCode(), style: AppTextStyles.label),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invite Students', style: AppTextStyles.title),
                          const SizedBox(height: 4),
                          Text(
                            'Share a backend-generated invite link or QR code.',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isRefreshing ? null : () => _loadInvite(refresh: true),
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _InviteAction(
                      icon: Icons.link,
                      label: 'Copy Link',
                      onTap: _copyLink,
                    ),
                    _InviteAction(
                      icon: Icons.qr_code,
                      label: 'QR Code',
                      onTap: _showQrDialog,
                    ),
                    _InviteAction(
                      icon: Icons.refresh,
                      label: 'Refresh',
                      onTap: () => _loadInvite(refresh: true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _inviteUrl(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
    );
  }
}

class _InviteAction extends StatelessWidget {
  const _InviteAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
