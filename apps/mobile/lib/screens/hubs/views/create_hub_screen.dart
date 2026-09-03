import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/home/widgets/empty_home_state.dart';
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
    if (_hubNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please enter a hub name")));
      return;
    }
    context.push(
      '/hub-permissions',
      extra: {
        'name': _hubNameController.text.trim(),
        'description': _descriptionController.text.trim(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
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
                'Create a hub and keep your class in sync.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
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
