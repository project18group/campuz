import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/app_text_field.dart';
import 'package:mobile/shared/widgets/primary_button.dart';
import 'package:mobile/screens/home/widgets/empty_home_state.dart';

class JoinHubScreen extends StatefulWidget {
  const JoinHubScreen({super.key});

  @override
  State<JoinHubScreen> createState() => _JoinHubScreenState();
}

class _JoinHubScreenState extends State<JoinHubScreen> {
  final _inviteController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  String _extractCode(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final uri = Uri.tryParse(text);
    if (uri != null) {
      final queryCode = uri.queryParameters['code']?.trim();
      if (queryCode != null && queryCode.isNotEmpty) {
        return queryCode.toUpperCase();
      }
      final parts = uri.pathSegments.where((segment) => segment.trim().isNotEmpty);
      if (parts.isNotEmpty) {
        return parts.last.trim().toUpperCase();
      }
    }
    return text.toUpperCase();
  }

  Future<void> _joinHub() async {
    final code = _extractCode(_inviteController.text);
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an invite code')),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      await AuthApiService.joinHubWithInviteCode(code: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You joined the hub successfully')),
      );
      context.go('/home');
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to join that hub right now')),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Hero(
                  tag: homeEmptyHeroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: SvgPicture.asset(
                      'assets/images/firsttime_home.svg',
                      height: 150,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome in. Join your first hub to start receiving updates.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text('Join Academic Hub', style: AppTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                'Enter an invite code, paste a backend invite link, or scan a QR code that opens the same link.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 40),
              AppTextField(
                controller: _inviteController,
                label: 'Invite Code',
                hintText: 'Paste invite code or invite link',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: _isJoining ? 'Joining...' : 'Join Hub',
                onPressed: _isJoining ? null : _joinHub,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR', style: AppTextStyles.body),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('QR scanning will plug into the same invite join flow.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
