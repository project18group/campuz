import re

with open('apps/backend/api/models.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update Broadcast
content = content.replace(
    'content = models.TextField()',
    'content = models.TextField()\n    attachment = models.FileField(upload_to="broadcasts/%Y/%m/%d/", null=True, blank=True)'
)

# 2. Update Resource
content = content.replace(
    'url = models.URLField(max_length=1000)',
    'url = models.URLField(max_length=1000, blank=True, null=True)\n    file = models.FileField(upload_to="resources/%Y/%m/%d/", null=True, blank=True)'
)

# 3. Update TaskItem (attachment)
content = content.replace(
    'description = models.TextField(blank=True, null=True)\n    course_name = models.CharField(max_length=100)',
    'description = models.TextField(blank=True, null=True)\n    attachment = models.FileField(upload_to="tasks/attachments/%Y/%m/%d/", null=True, blank=True)\n    course_name = models.CharField(max_length=100)'
)

# 4. Update TaskItem (submission_file)
content = content.replace(
    'submission_link = models.URLField(max_length=1000, blank=True, null=True)\n    submitted_at = models.DateTimeField(null=True, blank=True)',
    'submission_link = models.URLField(max_length=1000, blank=True, null=True)\n    submission_file = models.FileField(upload_to="tasks/submissions/%Y/%m/%d/", null=True, blank=True)\n    submitted_at = models.DateTimeField(null=True, blank=True)'
)

with open('apps/backend/api/models.py', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated models.py successfully.')
