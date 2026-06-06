import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/app_text_field.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text("Profile Info", style: AppTextStyles.heading),

              const SizedBox(height: 8),

              Text(
                'Please provide a suitable username and an optional profile picture.',
                style: AppTextStyles.body,
              ),

              const SizedBox(height: 40),

              Center(
                child: Stack(
                  children: [
                    const CircleAvatar(
                      radius: 55,
                      child: Icon(Icons.person, size: 50),
                    ),

                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 25,
                        child: IconButton(
                          iconSize: 18,
                          onPressed: () {},
                          icon: Icon(Icons.add_a_photo_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              const AppTextField(label: "Username", hintText: "@user_name"),

              const SizedBox(height: 360),

              // const AppTextField(label: "Level", hintText: "Level 100"),

              // const SizedBox(height: 300),
              PrimaryButton(
                text: "Finish",
                onPressed: () {
                  context.go("/account-setup");
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
