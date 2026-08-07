import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InviteCard extends StatelessWidget {
  const InviteCard({super.key});

  Future<void> _copyLink(BuildContext context) async {
    const inviteLink = "https://campuz.app/invite/abc123";

    await Clipboard.setData(const ClipboardData(text: inviteLink));

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Invite link copied")));
  }

  void _showQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Join Computer Science 2029", style: AppTextStyles.title),
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: QrImageView(data: "https://campuz.app/invite/abc123"),
                ),
                const SizedBox(height: 16),
                Text("ABC123", style: AppTextStyles.label),
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text("Invite Students", style: AppTextStyles.title),

          const SizedBox(height: 8),

          Text("Share your hub with classmates.", style: AppTextStyles.body),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,

            children: [
              _InviteAction(
                icon: Icons.link,

                label: "Copy Link",
                onTap: () {
                  _copyLink(context);
                },
              ),

              _InviteAction(
                icon: Icons.qr_code,
                label: "QR Code",
                onTap: () {
                  _showQrDialog(context);
                },
              ),

              _InviteAction(
                icon: Icons.person_add,
                label: "Add",
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) {
                      return SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.link),

                              title: const Text("Share Invite Link"),

                              onTap: () {
                                Navigator.pop(context);
                                _copyLink(context);
                              },
                            ),

                            ListTile(
                              leading: const Icon(Icons.qr_code),

                              title: const Text("Show QR Code"),

                              onTap: () {
                                Navigator.pop(context);

                                _showQrDialog(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InviteAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
