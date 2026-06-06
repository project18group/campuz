import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';
import 'package:pinput/pinput.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // adjust to navigate back to the create account screen
        leading: Icon(Icons.arrow_back),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Text("Verify Your Account", style: AppTextStyles.heading),

              const SizedBox(height: 12),

              Text(
                "Enter the 6-digit verification code sent to your email.",
                style: AppTextStyles.body,
              ),

              const SizedBox(height: 40),

              Center(child: 
              Pinput
              (
                length: 6,
                //listen for incoming sms and extract code from it
                // smsRetriever: ,
              )
              ),

              const SizedBox(height: 24),

              Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text("Resend Code"),
                ),
              ),

              const Spacer(),

              PrimaryButton(
                text: "Verify & Continue",
                onPressed: () {
                  context.go("/complete-profile");
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
