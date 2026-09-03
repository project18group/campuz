import re

with open('apps/mobile/lib/screens/hub/views/section_tasks_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'dart:io';" not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'dart:io';\nimport 'package:file_picker/file_picker.dart';\nimport 'package:flutter/material.dart';"
    )

# 1. Update _openTaskSheet to include attachment picker
old_task_sheet_start = """    _dueDate = _parseDueDate(task ?? const {}) ?? DateTime.now().add(const Duration(days: 3));
    bool sending = false;

    await showModalBottomSheet<void>("""

new_task_sheet_start = """    _dueDate = _parseDueDate(task ?? const {}) ?? DateTime.now().add(const Duration(days: 3));
    bool sending = false;
    File? selectedAttachment;

    await showModalBottomSheet<void>("""

content = content.replace(old_task_sheet_start, new_task_sheet_start)

old_task_create = """                } else {
                  await AuthApiService.createHubTask(
                    hubId: widget.hubId,
                    title: title,
                    description: description,
                    courseName: courseName,
                    dueDate: _dueDate,
                    assignedToId: assigneeId,
                  );
                }"""

new_task_create = """                } else {
                  await AuthApiService.createHubTask(
                    hubId: widget.hubId,
                    title: title,
                    description: description,
                    courseName: courseName,
                    dueDate: _dueDate,
                    assignedToId: assigneeId,
                    attachment: selectedAttachment,
                  );
                }"""

content = content.replace(old_task_create, new_task_create)

old_task_ui = """                        decoration: const InputDecoration(labelText: 'Description (optional)'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _courseController,"""

new_task_ui = """                        decoration: const InputDecoration(labelText: 'Description (optional)'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      if (!isEditing)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await FilePicker.platform.pickFiles();
                                  if (result != null && result.files.single.path != null) {
                                    setSheetState(() {
                                      selectedAttachment = File(result.files.single.path!);
                                    });
                                  }
                                },
                                icon: const Icon(Icons.attach_file),
                                label: Text(selectedAttachment != null ? 'File selected' : 'Attach File (optional)'),
                              ),
                            ),
                            if (selectedAttachment != null)
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setSheetState(() => selectedAttachment = null),
                              ),
                          ],
                        ),
                      if (!isEditing) const SizedBox(height: 12),
                      TextField(
                        controller: _courseController,"""

content = content.replace(old_task_ui, new_task_ui)


# 2. Update Submit Sheet to include file picker
old_submit_start = """    final submissionLinkController = TextEditingController(
      text: (task['submission_link'] as String? ?? '').trim(),
    );
    bool sending = false;

    await showModalBottomSheet<void>("""

new_submit_start = """    final submissionLinkController = TextEditingController(
      text: (task['submission_link'] as String? ?? '').trim(),
    );
    bool sending = false;
    File? submissionFile;

    await showModalBottomSheet<void>("""

content = content.replace(old_submit_start, new_submit_start)

# Safer replacement for submitHubTask
old_submit_call = """                await AuthApiService.submitHubTask(
                  taskId: id,
                  submissionText: submissionTextController.text.trim(),
                  submissionLink: submissionLinkController.text.trim(),
                );"""

new_submit_call = """                await AuthApiService.submitHubTask(
                  taskId: id,
                  submissionText: submissionTextController.text.trim(),
                  submissionLink: submissionLinkController.text.trim(),
                  submissionFile: submissionFile,
                );"""

content = content.replace(old_submit_call, new_submit_call)

# the UI part of submitHubTask
old_submit_ui = """                      const SizedBox(height: 12),
                      TextField(
                        controller: submissionLinkController,
                        decoration: const InputDecoration(labelText: 'Link (optional)'),
                      ),
                      const SizedBox(height: 16),"""

new_submit_ui = """                      const SizedBox(height: 12),
                      TextField(
                        controller: submissionLinkController,
                        decoration: const InputDecoration(labelText: 'Link (optional)'),
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
                                    submissionFile = File(result.files.single.path!);
                                  });
                                }
                              },
                              icon: const Icon(Icons.attach_file),
                              label: Text(submissionFile != null ? 'File selected' : 'Upload File (optional)'),
                            ),
                          ),
                          if (submissionFile != null)
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setSheetState(() => submissionFile = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),"""

content = content.replace(old_submit_ui, new_submit_ui)

with open('apps/mobile/lib/screens/hub/views/section_tasks_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated section_tasks_screen.dart")
