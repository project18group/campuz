import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';

class JoinHubScreen extends StatelessWidget {
  const JoinHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            context.go("/home");
          },
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Join Academic Hub', style: AppTextStyles.heading),

              const SizedBox(height: 8),

              Text(
                'Enter an invite code, scan a QR code, or use an invitation link shared by your class representative.',
                style: AppTextStyles.body,
              ),

              const SizedBox(height: 40),

              const AppTextField(
                label: 'Invite Code',
                hintText: 'Enter invite code',
              ),

              const SizedBox(height: 24),

              PrimaryButton(
                text: 'Join Hub',
                onPressed: () {
                  // Navigate to Hub Dashboard later
                },
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
                  onPressed: () {},

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
