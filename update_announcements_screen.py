import re

with open('apps/mobile/lib/screens/hub/views/section_announcements_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'dart:io';" not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'dart:io';\nimport 'package:file_picker/file_picker.dart';\nimport 'package:flutter/material.dart';"
    )

# Add selectedFile to state
old_composer = """  void _openComposer() {
    if (!_canCreateBroadcasts) return;

    showModalBottomSheet<void>("""

new_composer = """  File? _selectedFile;

  void _openComposer() {
    if (!_canCreateBroadcasts) return;
    _selectedFile = null;

    showModalBottomSheet<void>("""

content = content.replace(old_composer, new_composer)

# Update _createBroadcast to include file
old_create = """      final result = await AuthApiService.createHubBroadcast(
        hubId: widget.hubId,
        title: title,
        content: content,
        priority: _priority,
        sendAsSms: _sendAsSms && _canCreateBroadcasts,
      );"""

new_create = """      final result = await AuthApiService.createHubBroadcast(
        hubId: widget.hubId,
        title: title,
        content: content,
        priority: _priority,
        sendAsSms: _sendAsSms && _canCreateBroadcasts,
        attachment: _selectedFile,
      );"""

content = content.replace(old_create, new_create)

# Add UI for file picker
old_ui = """                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Content',
                        ),
                      ),
                      const SizedBox(height: 12),"""

new_ui = """                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Content',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles();
                                if (result != null && result.files.single.path != null) {
                                  setSheetState(() {
                                    _selectedFile = File(result.files.single.path!);
                                  });
                                }
                              },
                              icon: const Icon(Icons.attach_file),
                              label: Text(_selectedFile != null ? 'File selected' : 'Attach File (optional)'),
                            ),
                          ),
                          if (_selectedFile != null)
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setSheetState(() => _selectedFile = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),"""

content = content.replace(old_ui, new_ui)

with open('apps/mobile/lib/screens/hub/views/section_announcements_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated section_announcements_screen.dart")
