import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/app_avatar.dart';

class EditHubSheet extends StatefulWidget {
  final Map<String, dynamic> hub;
  final VoidCallback onHubUpdated;

  const EditHubSheet({
    super.key,
    required this.hub,
    required this.onHubUpdated,
  });

  @override
  State<EditHubSheet> createState() => _EditHubSheetState();
}

class _EditHubSheetState extends State<EditHubSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  File? _selectedImage;
  bool _isSaving = false;

  int get _hubId {
    final value = widget.hub['id'];
    return value is int ? value : int.tryParse('$value') ?? 0;
  }

  String get _currentAvatarUrl =>
      (widget.hub['cover_image_url'] as String? ?? '').trim();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: (widget.hub['name'] as String? ?? '').trim(),
    );
    _descController = TextEditingController(
      text: (widget.hub['description'] as String? ?? '').trim(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hub name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await AuthApiService.updateHub(
        hubId: _hubId,
        name: name,
        description: _descController.text.trim(),
        coverImageFile: _selectedImage,
      );

      if (!mounted) return;
      widget.onHubUpdated();
      Navigator.pop(context);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update hub info')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Edit Hub Info',
                style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    if (_selectedImage != null)
                      CircleAvatar(
                        radius: 44,
                        backgroundImage: FileImage(_selectedImage!),
                      )
                    else
                      AppAvatar(
                        avatarUrl: _currentAvatarUrl,
                        fallbackName: _nameController.text,
                        size: 88,
                      ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: AppColors.surface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Hub Name',
                  hintText: 'Enter hub name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter hub description',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
