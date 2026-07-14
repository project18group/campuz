import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/app_text_field.dart';
import 'package:mobile/shared/widgets/primary_button.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  String? _imagePath;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // TODO: Connect to Django REST Framework
    // PATCH /api/users/me/ with {username, avatar} (multipart form or JSON)
    await Future.delayed(const Duration(seconds: 1)); // Placeholder delay

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      context.go('/account-setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                    CircleAvatar(
                      radius: 55,
                      backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
                      child: _imagePath == null ? const Icon(Icons.person, size: 50) : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 20,
                        child: IconButton(
                          iconSize: 18,
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_a_photo_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              AppTextField(
                controller: _usernameController,
                label: "Username",
                hintText: "@user_name",
              ),
              const SizedBox(height: 60),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : PrimaryButton(
                      text: "Finish",
                      onPressed: _saveProfile,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
