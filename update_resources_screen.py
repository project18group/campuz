import re

with open('apps/mobile/lib/screens/hub/views/section_resources_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'dart:io';" not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'dart:io';\nimport 'package:file_picker/file_picker.dart';\nimport 'package:flutter/material.dart';"
    )

old_sheet = """    final titleController = TextEditingController();
    final urlController = TextEditingController();
    String resourceType = 'pdf';
    bool sending = false;

    await showModalBottomSheet<void>("""

new_sheet = """    final titleController = TextEditingController();
    final urlController = TextEditingController();
    String resourceType = 'pdf';
    bool sending = false;
    File? selectedFile;

    await showModalBottomSheet<void>("""

content = content.replace(old_sheet, new_sheet)

old_submit = """            Future<void> submit() async {
              final title = titleController.text.trim();
              final url = urlController.text.trim();
              if (title.isEmpty || url.isEmpty || sending) return;
              setSheetState(() => sending = true);
              try {
                final created = await AuthApiService.createHubResource(
                  hubId: widget.hubId,
                  title: title,
                  url: url,
                  resourceType: resourceType,
                );"""

new_submit = """            Future<void> submit() async {
              final title = titleController.text.trim();
              final url = urlController.text.trim();
              if (title.isEmpty || (url.isEmpty && selectedFile == null) || sending) return;
              setSheetState(() => sending = true);
              try {
                final created = await AuthApiService.createHubResource(
                  hubId: widget.hubId,
                  title: title,
                  url: url.isEmpty ? null : url,
                  file: selectedFile,
                  resourceType: resourceType,
                );"""

content = content.replace(old_submit, new_submit)

old_ui = """                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: resourceType,
                        decoration: const InputDecoration(labelText: 'Type'),"""

new_ui = """                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles();
                                if (result != null && result.files.single.path != null) {
                                  setSheetState(() {
                                    selectedFile = File(result.files.single.path!);
                                  });
                                }
                              },
                              icon: const Icon(Icons.attach_file),
                              label: Text(selectedFile != null ? 'File selected' : 'Pick File'),
                            ),
                          ),
                          if (selectedFile != null)
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setSheetState(() => selectedFile = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: resourceType,
                        decoration: const InputDecoration(labelText: 'Type'),"""

content = content.replace(old_ui, new_ui)

# Update _openResource to handle file vs url properly
old_open = """  Future<void> _openResource(Map<String, dynamic> resource) async {
    final url = (resource['url'] as String? ?? '').trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL is available for this resource.')),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid resource URL.')),
      );
      return;
    }"""

new_open = """  Future<void> _openResource(Map<String, dynamic> resource) async {
    String? url = resource['file'] as String?;
    if (url == null || url.trim().isEmpty) {
      url = resource['url'] as String?;
    }
    url = (url ?? '').trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL or file is available for this resource.')),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid resource URL.')),
      );
      return;
    }"""

content = content.replace(old_open, new_open)

with open('apps/mobile/lib/screens/hub/views/section_resources_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated section_resources_screen.dart")
