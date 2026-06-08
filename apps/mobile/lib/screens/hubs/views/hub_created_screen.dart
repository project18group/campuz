import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';
import 'package:qr_flutter/qr_flutter.dart';

class HubCreatedScreen extends StatelessWidget {
  const HubCreatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const hubName = "Computer Science 2029";
    const inviteCode = "abc123";
    const inviteLink = "https://campuz.app/invite/abc123";

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Academic Hub Ready", style: AppTextStyles.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [
            const SizedBox(height: 24),

            Text(
              hubName,
              style: AppTextStyles.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Text("", style: AppTextStyles.title),

            const SizedBox(height: 18),

            Text(
              'Invite students to join your academic hub using the QR code or invite link below.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            Container(
              // width: double.infinity,
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(),
              ),

              child: Column(
                children: [
                  QrImageView(data: inviteLink, size: 220),
                  const SizedBox(height: 16),

                  Text("Invite Code", style: AppTextStyles.body),

                  const SizedBox(height: 4),
                  Text(inviteCode.toUpperCase(), style: AppTextStyles.label),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(),
              ),
              child: Text(inviteLink, textAlign: TextAlign.center),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: inviteLink),
                  );

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invite link copied")),
                  );
                },
                child: Text('Copy Invite Link'),
              ),
            ),

            const Spacer(),

            PrimaryButton(
              text: "Continue To Hub",
              onPressed: () {
                context.go("/hub-chat");
              },
            ),
          ],
        ),
      ),
    );
  }
}
