import re

with open('apps/backend/api/serializers.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. BroadcastSerializer
content = content.replace(
    '        fields = [\n            "id",\n            "hub",\n            "sender",\n            "sender_name",\n            "title",\n            "content",\n            "priority",\n            "timestamp",\n        ]',
    '        fields = [\n            "id",\n            "hub",\n            "sender",\n            "sender_name",\n            "title",\n            "content",\n            "attachment",\n            "priority",\n            "timestamp",\n        ]'
)

# BroadcastCreateSerializer
content = content.replace(
    'class BroadcastCreateSerializer(serializers.Serializer):\n    title = serializers.CharField(max_length=200)\n    content = serializers.CharField()\n    priority = serializers.ChoiceField(choices=Broadcast.PRIORITY_CHOICES, default="normal")',
    'class BroadcastCreateSerializer(serializers.Serializer):\n    title = serializers.CharField(max_length=200)\n    content = serializers.CharField()\n    attachment = serializers.FileField(required=False, allow_null=True)\n    priority = serializers.ChoiceField(choices=Broadcast.PRIORITY_CHOICES, default="normal")'
)

# 2. ResourceSerializer
content = content.replace(
    '        fields = [\n            "id",\n            "hub",\n            "title",\n            "resource_type",\n            "url",\n            "uploaded_by",\n            "uploaded_by_name",\n            "upload_date",\n        ]',
    '        fields = [\n            "id",\n            "hub",\n            "title",\n            "resource_type",\n            "url",\n            "file",\n            "uploaded_by",\n            "uploaded_by_name",\n            "upload_date",\n        ]'
)

# ResourceCreateSerializer
content = content.replace(
    'class ResourceCreateSerializer(serializers.Serializer):\n    title = serializers.CharField(max_length=200)\n    resource_type = serializers.ChoiceField(choices=Resource.RESOURCE_TYPE_CHOICES)\n    url = serializers.URLField(max_length=1000)',
    'class ResourceCreateSerializer(serializers.Serializer):\n    title = serializers.CharField(max_length=200)\n    resource_type = serializers.ChoiceField(choices=Resource.RESOURCE_TYPE_CHOICES)\n    url = serializers.URLField(max_length=1000, required=False, allow_blank=True, allow_null=True)\n    file = serializers.FileField(required=False, allow_null=True)'
)

# 3. TaskSerializer
content = content.replace(
    '            "description",\n            "course_name",',
    '            "description",\n            "attachment",\n            "course_name",'
)
content = content.replace(
    '            "submission_text",\n            "submission_link",',
    '            "submission_text",\n            "submission_link",\n            "submission_file",'
)

# TaskCreateSerializer
content = content.replace(
    '    description = serializers.CharField(required=False, allow_blank=True, allow_null=True)\n    course_name = serializers.CharField(max_length=100)',
    '    description = serializers.CharField(required=False, allow_blank=True, allow_null=True)\n    attachment = serializers.FileField(required=False, allow_null=True)\n    course_name = serializers.CharField(max_length=100)'
)

# TaskSubmitSerializer
content = content.replace(
    '    submission_link = serializers.URLField(required=False, allow_blank=True, allow_null=True)',
    '    submission_link = serializers.URLField(required=False, allow_blank=True, allow_null=True)\n    submission_file = serializers.FileField(required=False, allow_null=True)'
)

with open('apps/backend/api/serializers.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated serializers.py")
