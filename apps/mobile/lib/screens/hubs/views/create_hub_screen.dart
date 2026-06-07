import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/app_text_field.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class CreateHubScreen extends StatefulWidget {
  const CreateHubScreen({super.key});

  @override
  State<CreateHubScreen> createState() => _CreateHubScreenState();
}

class _CreateHubScreenState extends State<CreateHubScreen> {
  final _hubNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _hubNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _continue() {
    print(_hubNameController.text);
    if (_hubNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please enter a hub name")));
      return;
    }
    context.push("/hub-permissions");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            context.go("/select-contact");
          },
        ),
        title: Text("Create Academic Hub", style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              AppTextField(
                controller: _hubNameController,
                hintText: "CS'29",
                label: 'Hub Name',
              ),

              const SizedBox(height: 24),

              const SizedBox(height: 8),

              AppTextField(
                controller: _descriptionController,
                hintText:
                    'Computer Science students of the 2029 graduating class.',
                label: "Description (Optional)",
                maxLines: 3,
              ),

              const Spacer(),

              PrimaryButton(text: 'Next', onPressed: _continue),
            ],
          ),
        ),
      ),
    );
  }
}
