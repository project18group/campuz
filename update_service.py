import re

with open('apps/mobile/lib/core/services/auth_api_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace createHubResource
old_resource = """  static Future<Map<String, dynamic>> createHubResource({
    required int hubId,
    required String title,
    required String url,
    required String resourceType,
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/hubs/$hubId/resources/'),
        headers: _headers(token),
        body: jsonEncode({
          'title': title,
          'url': url,
          'resource_type': resourceType,
        }),
      ),
    );
  }"""

new_resource = """  static Future<Map<String, dynamic>> createHubResource({
    required int hubId,
    required String title,
    String? url,
    required String resourceType,
    File? file,
  }) async {
    if (file == null) {
      return _authorized(
        (token) => _client.post(
          Uri.parse('$_baseUrl/hubs/$hubId/resources/'),
          headers: _headers(token),
          body: jsonEncode({
            'title': title,
            if (url != null) 'url': url,
            'resource_type': resourceType,
          }),
        ),
      );
    }
    return _authorizedMultipart(
      (token) async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/hubs/$hubId/resources/'),
        );
        request.headers.addAll(_headers(token, includeContentType: false));
        request.fields['title'] = title;
        if (url != null) request.fields['url'] = url;
        request.fields['resource_type'] = resourceType;
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: p.basename(file.path),
          ),
        );
        return request.send();
      },
    );
  }"""

content = content.replace(old_resource, new_resource)

# Replace createHubBroadcast
old_broadcast = """  static Future<Map<String, dynamic>> createHubBroadcast({
    required int hubId,
    required String title,
    required String content,
    String priority = 'normal',
    bool sendAsSms = false,
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/hubs/$hubId/broadcasts/'),
        headers: _headers(token),
        body: jsonEncode({
          'title': title,
          'content': content,
          'priority': priority,
          'send_as_sms': sendAsSms,
        }),
      ),
    );
  }"""

new_broadcast = """  static Future<Map<String, dynamic>> createHubBroadcast({
    required int hubId,
    required String title,
    required String content,
    String priority = 'normal',
    bool sendAsSms = false,
    File? attachment,
  }) async {
    if (attachment == null) {
      return _authorized(
        (token) => _client.post(
          Uri.parse('$_baseUrl/hubs/$hubId/broadcasts/'),
          headers: _headers(token),
          body: jsonEncode({
            'title': title,
            'content': content,
            'priority': priority,
            'send_as_sms': sendAsSms,
          }),
        ),
      );
    }
    return _authorizedMultipart(
      (token) async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/hubs/$hubId/broadcasts/'),
        );
        request.headers.addAll(_headers(token, includeContentType: false));
        request.fields['title'] = title;
        request.fields['content'] = content;
        request.fields['priority'] = priority;
        request.fields['send_as_sms'] = sendAsSms.toString();
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            attachment.path,
            filename: p.basename(attachment.path),
          ),
        );
        return request.send();
      },
    );
  }"""

content = content.replace(old_broadcast, new_broadcast)

# Replace createHubTask
old_task = """  static Future<Map<String, dynamic>> createHubTask({
    required int hubId,
    required String title,
    required String courseName,
    required DateTime dueDate,
    required int assignedToId,
    String? description,
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/hubs/$hubId/tasks/'),
        headers: _headers(token),
        body: jsonEncode({
          'title': title,
          'course_name': courseName,
          'due_date': dueDate.toIso8601String(),
          'assigned_to_id': assignedToId,
          if (description != null && description.isNotEmpty)
            'description': description,
        }),
      ),
    );
  }"""

new_task = """  static Future<Map<String, dynamic>> createHubTask({
    required int hubId,
    required String title,
    required String courseName,
    required DateTime dueDate,
    required int assignedToId,
    String? description,
    File? attachment,
  }) async {
    if (attachment == null) {
      return _authorized(
        (token) => _client.post(
          Uri.parse('$_baseUrl/hubs/$hubId/tasks/'),
          headers: _headers(token),
          body: jsonEncode({
            'title': title,
            'course_name': courseName,
            'due_date': dueDate.toIso8601String(),
            'assigned_to_id': assignedToId,
            if (description != null && description.isNotEmpty)
              'description': description,
          }),
        ),
      );
    }
    return _authorizedMultipart(
      (token) async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/hubs/$hubId/tasks/'),
        );
        request.headers.addAll(_headers(token, includeContentType: false));
        request.fields['title'] = title;
        request.fields['course_name'] = courseName;
        request.fields['due_date'] = dueDate.toIso8601String();
        request.fields['assigned_to_id'] = assignedToId.toString();
        if (description != null && description.isNotEmpty) {
          request.fields['description'] = description;
        }
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            attachment.path,
            filename: p.basename(attachment.path),
          ),
        );
        return request.send();
      },
    );
  }"""

content = content.replace(old_task, new_task)


# Replace submitHubTask
old_submit = """  static Future<Map<String, dynamic>> submitHubTask({
    required int taskId,
    String? submissionText,
    String? submissionLink,
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/tasks/$taskId/submit/'),
        headers: _headers(token),
        body: jsonEncode({
          if (submissionText != null) 'submission_text': submissionText,
          if (submissionLink != null) 'submission_link': submissionLink,
        }),
      ),
    );
  }"""

new_submit = """  static Future<Map<String, dynamic>> submitHubTask({
    required int taskId,
    String? submissionText,
    String? submissionLink,
    File? submissionFile,
  }) async {
    if (submissionFile == null) {
      return _authorized(
        (token) => _client.post(
          Uri.parse('$_baseUrl/tasks/$taskId/submit/'),
          headers: _headers(token),
          body: jsonEncode({
            if (submissionText != null) 'submission_text': submissionText,
            if (submissionLink != null) 'submission_link': submissionLink,
          }),
        ),
      );
    }
    return _authorizedMultipart(
      (token) async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/tasks/$taskId/submit/'),
        );
        request.headers.addAll(_headers(token, includeContentType: false));
        if (submissionText != null) {
          request.fields['submission_text'] = submissionText;
        }
        if (submissionLink != null) {
          request.fields['submission_link'] = submissionLink;
        }
        request.files.add(
          await http.MultipartFile.fromPath(
            'submission_file',
            submissionFile.path,
            filename: p.basename(submissionFile.path),
          ),
        );
        return request.send();
      },
    );
  }"""

content = content.replace(old_submit, new_submit)

with open('apps/mobile/lib/core/services/auth_api_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated auth_api_service.dart")
