import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:mobile/core/services/auth_session.dart';
import 'package:mobile/core/services/secure_token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthApiException implements Exception {
  final String message;
  const AuthApiException(this.message);
  @override
  String toString() => message;
}

class AuthApiService {
  AuthApiService._();

  static final http.Client _client = http.Client();
  static const _cachedCurrentUserKey = 'campuz_cached_current_user';

  static String get _baseUrl {
    const envBaseUrl = String.fromEnvironment('CAMPUZ_API_BASE_URL');
    if (envBaseUrl.isNotEmpty) return envBaseUrl;
    return "https://campuz-api.onrender.com/api";
  }

  // ---------------------------------------------------------------------------
  // Phone-OTP authentication
  // ---------------------------------------------------------------------------

  /// Requests a 6-digit OTP sent to [phoneNumber].
  /// [fullName] is optional and only used to prefill a pending profile.
  static Future<Map<String, dynamic>> requestOtp({
    required String phoneNumber,
    String? fullName,
  }) async {
    final body = <String, dynamic>{'phone_number': phoneNumber};
    if (fullName != null && fullName.trim().isNotEmpty) {
      body['full_name'] = fullName.trim();
    }
    return _postJson('/auth/request-otp/', body: body);
  }

  /// Verifies [otpCode] for [phoneNumber].
  ///
  /// On success returns `{ "access": "...", "refresh": "...", "is_new_user": bool }`.
  /// Tokens are persisted to secure storage automatically.
  static Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    final response = await _postJson(
      '/auth/verify-otp/',
      body: {'phone_number': phoneNumber, 'otp_code': otpCode},
    );
    await _persistTokens(response);
    return response;
  }

  // ---------------------------------------------------------------------------
  // Profile setup (authenticated)
  // ---------------------------------------------------------------------------

  /// Saves the user's [displayName], optional [avatarUrl], and optional
  /// [adminCode].  If [adminCode] is a valid invitation code, the backend
  /// grants can_create_hubs on that account.
  static Future<Map<String, dynamic>> profileSetup({
    String? displayName,
    String? avatarUrl,
    File? avatarFile,
    bool removeAvatar = false,
    String? adminCode,
  }) async {
    final needsMultipart = avatarFile != null || removeAvatar;
    final body = <String, dynamic>{};
    if (displayName != null && displayName.isNotEmpty) {
      body['display_name'] = displayName;
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      body['avatar_url'] = avatarUrl;
    }
    if (adminCode != null && adminCode.isNotEmpty) {
      body['admin_code'] = adminCode.trim().toUpperCase();
    }
    if (!needsMultipart) {
      return _authorized(
        (token) => _client.patch(
          Uri.parse('$_baseUrl/auth/profile-setup/'),
          headers: _headers(token),
          body: jsonEncode(body),
        ),
      );
    }

    return _authorizedMultipart(
      (token) async {
        final request = http.MultipartRequest(
          'PATCH',
          Uri.parse('$_baseUrl/auth/profile-setup/'),
        );
        request.headers.addAll(_headers(token, includeContentType: false));
        request.fields.addAll(
          body.map((key, value) => MapEntry(key, value.toString())),
        );
        if (removeAvatar) {
          request.fields['remove_avatar'] = 'true';
        }
        if (avatarFile != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'avatar_file',
              avatarFile.path,
              filename: p.basename(avatarFile.path),
            ),
          );
        }
        return request.send();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // User discovery
  // ---------------------------------------------------------------------------

  /// Returns registered Campuz users matching [query] (name / phone).
  /// Pass an empty string to return all verified users.
  static Future<List<Map<String, dynamic>>> searchUsers({
    String query = '',
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/users/search/',
    ).replace(queryParameters: query.isNotEmpty ? {'q': query} : null);
    final result = await _authorized(
      (token) => _client.get(uri, headers: _headers(token)),
    );
    final list = result['data'];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    // Backend returns a raw list — wrap it for consistency.
    return <Map<String, dynamic>>[];
  }

  /// Syncs contacts by passing a list of phone numbers to the backend.
  /// Returns a list of matched users on the platform.
  static Future<List<Map<String, dynamic>>> syncContacts({
    required List<String> phoneNumbers,
  }) async {
    final result = await _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/users/sync-contacts/'),
        headers: _headers(token),
        body: jsonEncode({'phone_numbers': phoneNumbers}),
      ),
    );
    final list = result['data'];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  // ---------------------------------------------------------------------------
  // Direct conversations
  // ---------------------------------------------------------------------------

  /// Lists all direct conversations for the current user.
  static Future<List<Map<String, dynamic>>> getDirectConversations() async {
    final result = await _authorized(
      (token) => _client.get(
        Uri.parse('$_baseUrl/conversations/direct/'),
        headers: _headers(token),
      ),
    );
    final list = result['data'];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// Gets or creates a direct conversation with [otherUserId].
  /// Returns the conversation map including `id` and `created`.
  static Future<Map<String, dynamic>> getOrCreateDirectConversation({
    required int otherUserId,
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/conversations/direct/'),
        headers: _headers(token),
        body: jsonEncode({'user_id': otherUserId}),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getDirectMessages({
    required int conversationId,
  }) async {
    final result = await _authorized(
      (token) => _client.get(
        Uri.parse('$_baseUrl/conversations/direct/$conversationId/messages/'),
        headers: _headers(token),
      ),
    );
    final list = result['data'];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }


  // ---------------------------------------------------------------------------
  // Hubs
  // ---------------------------------------------------------------------------


  // ---------------------------------------------------------------------------
  // Hub Sections
  // ---------------------------------------------------------------------------

  /// Creates a new section within a hub (Admin only).
  static Future<Map<String, dynamic>> createHubSection({
    required int hubId,
    required String title,
    required String sectionType,
    String description = '',
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/hubs/$hubId/sections/'),
        headers: _headers(token),
        body: jsonEncode({
          'title': title,
          'section_type': sectionType,
          'description': description,
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Messaging
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getHubs() async {
    final result = await _authorized(
      (token) => _client.get(
        Uri.parse('$_baseUrl/hubs/'),
        headers: _headers(token),
      ),
    );
    final list = result['data'];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  static Future<Map<String, dynamic>> createHub({
    required String name,
    String? description,
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/hubs/'),
        headers: _headers(token),
        body: jsonEncode({
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
        }),
      ),
    );
  }

  static Future<Map<String, dynamic>> updateHub({
    required int hubId,
    String? name,
    String? description,
    File? coverImageFile,
  }) async {
    final needsMultipart = coverImageFile != null;
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) {
      body['name'] = name;
    }
    if (description != null) {
      body['description'] = description;
    }

    if (!needsMultipart) {
      return _authorized(
        (token) => _client.patch(
          Uri.parse('$_baseUrl/hubs/$hubId/'),
          headers: _headers(token),
          body: jsonEncode(body),
        ),
      );
    }

    return _authorizedMultipart(
      (token) async {
        final request = http.MultipartRequest(
          'PATCH',
          Uri.parse('$_baseUrl/hubs/$hubId/'),
        );
        request.headers.addAll(_headers(token, includeContentType: false));
        request.fields.addAll(
          body.map((key, value) => MapEntry(key, value.toString())),
        );
        request.files.add(
          await http.MultipartFile.fromPath(
            'cover_image_file',
            coverImageFile.path,
            filename: p.basename(coverImageFile.path),
          ),
        );
              return request.send();
      },
    );
  }

  static Future<Map<String, dynamic>> getHubMessages({
    required int hubId,
    int page = 1,
  }) async {
    final uri = Uri.parse('$_baseUrl/hubs/$hubId/messages/').replace(
      queryParameters: {'page': '$page'},
    );
    return _authorized(
      (token) => _client.get(uri, headers: _headers(token)),
    );
  }

  static Future<void> deleteMessage(int messageId) async {
    await _authorized(
      (token) => _client.delete(
        Uri.parse('$_baseUrl/messages/$messageId/'),
        headers: _headers(token),
      ),
    );
  }

  static Future<Map<String, dynamic>> sendHubMessage({
    required int hubId,
    required String content,
    bool sendAsSms = false,
    List<PlatformFile>? attachments,
  }) async {
    final needsMultipart = attachments != null && attachments.isNotEmpty;
    final body = <String, dynamic>{
      'content': content,
      'send_as_sms': sendAsSms,
    };

    if (!needsMultipart) {
      return _authorized(
        (token) => _client.post(
          Uri.parse('$_baseUrl/hubs/$hubId/messages/'),
          headers: _headers(token),
          body: jsonEncode(body),
        ),
      );
    }

    return _authorizedMultipart(
      (token) async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/hubs/$hubId/messages/'),
        );
        request.headers.addAll(_headers(token, includeContentType: false));
        request.fields.addAll(
          body.map((key, value) => MapEntry(key, value.toString())),
        );
        for (final file in attachments) {
          if (file.path != null) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'attachments',
                file.path!,
                filename: file.name,
              ),
            );
          }
        }
        return request.send();
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getBroadcasts() async {
    final result = await _authorized(
      (token) => _client.get(
        Uri.parse('$_baseUrl/broadcasts/'),
        headers: _headers(token),
      ),
    );
    final list = result['results'] ?? result['data'] ?? result;
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  static Future<Map<String, dynamic>> getHubBroadcasts({
    required int hubId,
    int page = 1,
  }) async {
    final uri = Uri.parse('$_baseUrl/hubs/$hubId/broadcasts/').replace(
      queryParameters: {'page': '$page'},
    );
    return _authorized(
      (token) => _client.get(uri, headers: _headers(token)),
    );
  }

  static Future<Map<String, dynamic>> createHubBroadcast({
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
  }

  static Future<Map<String, dynamic>> getHubTasks({
    required int hubId,
    int page = 1,
    String status = 'all',
    bool mine = false,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (mine) {
      query['mine'] = 'true';
    }
    final uri = Uri.parse('$_baseUrl/hubs/$hubId/tasks/').replace(
      queryParameters: query,
    );
    return _authorized(
      (token) => _client.get(uri, headers: _headers(token)),
    );
  }

  static Future<List<Map<String, dynamic>>> getTasks({
    int page = 1,
    String status = 'all',
    bool mine = true,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (mine) {
      query['mine'] = 'true';
    }
    final uri = Uri.parse('$_baseUrl/tasks/').replace(queryParameters: query);
    final result = await _authorized(
      (token) => _client.get(uri, headers: _headers(token)),
    );
    final list = result['results'] ?? result['data'] ?? result;
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  static Future<Map<String, dynamic>> createHubTask({
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
            'due_date': dueDate.toUtc().toIso8601String(),
            'assigned_to_id': assignedToId,
            if (description != null) 'description': description,
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
        request.fields['due_date'] = dueDate.toUtc().toIso8601String();
        request.fields['assigned_to_id'] = assignedToId.toString();
        if (description != null) {
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
  }

  static Future<Map<String, dynamic>> updateHubTask({
    required int taskId,
    String? title,
    String? description,
    String? courseName,
    DateTime? dueDate,
    int? assignedToId,
    String? status,
    String? submissionText,
    String? submissionLink,
    String? grade,
    String? feedback,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (courseName != null) body['course_name'] = courseName;
    if (dueDate != null) body['due_date'] = dueDate.toUtc().toIso8601String();
    if (assignedToId != null) body['assigned_to_id'] = assignedToId;
    if (status != null) body['status'] = status;
    if (submissionText != null) body['submission_text'] = submissionText;
    if (submissionLink != null) body['submission_link'] = submissionLink;
    if (grade != null) body['grade'] = grade;
    if (feedback != null) body['feedback'] = feedback;
    return _authorized(
      (token) => _client.patch(
        Uri.parse('$_baseUrl/tasks/$taskId/'),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
  }

  static Future<Map<String, dynamic>> deleteHubTask({
    required int taskId,
  }) async {
    return _authorized(
      (token) => _client.delete(
        Uri.parse('$_baseUrl/tasks/$taskId/'),
        headers: _headers(token),
      ),
    );
  }

  static Future<Map<String, dynamic>> submitHubTask({
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
  }

  static Future<Map<String, dynamic>> gradeHubTask({
    required int taskId,
    required String grade,
    String? feedback,
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/tasks/$taskId/grade/'),
        headers: _headers(token),
        body: jsonEncode({
          'grade': grade,
          if (feedback != null) 'feedback': feedback,
        }),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getResources({
    int? hubId,
    String query = '',
    String type = 'all',
  }) async {
    final uri = (hubId == null
            ? Uri.parse('$_baseUrl/resources/')
            : Uri.parse('$_baseUrl/hubs/$hubId/resources/'))
        .replace(
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        if (type.isNotEmpty && type != 'all') 'type': type,
      },
    );
    final result = await _authorized(
      (token) => _client.get(uri, headers: _headers(token)),
    );
    final list = result['results'] ?? result['data'] ?? result;
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  static Future<Map<String, dynamic>> createHubResource({
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
  }

  static Future<Map<String, dynamic>> deleteResource({
    required int resourceId,
  }) async {
    return _authorized(
      (token) => _client.delete(
        Uri.parse('$_baseUrl/resources/$resourceId/'),
        headers: _headers(token),
      ),
    );
  }

  static Future<Map<String, dynamic>> getHubMembers({
    required int hubId,
  }) async {
    return _authorized(
      (token) => _client.get(
        Uri.parse('$_baseUrl/hubs/$hubId/members/'),
        headers: _headers(token),
      ),
    );
  }

  static Future<Map<String, dynamic>> updateHubMembership({
    required int hubId,
    required String action,
    int? userId,
    List<int>? userIds,
  }) async {
    final body = <String, dynamic>{'action': action};
    if (userId != null) {
      body['user_id'] = userId;
    }
    if (userIds != null) {
      body['user_ids'] = userIds;
    }
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/hubs/$hubId/members/'),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
  }

  static Future<Map<String, dynamic>> promoteHubMember({
    required int hubId,
    required int userId,
  }) {
    return updateHubMembership(hubId: hubId, action: 'promote', userId: userId);
  }

  static Future<Map<String, dynamic>> demoteHubMember({
    required int hubId,
    required int userId,
  }) {
    return updateHubMembership(hubId: hubId, action: 'demote', userId: userId);
  }

  static Future<Map<String, dynamic>> removeHubMember({
    required int hubId,
    required int userId,
  }) {
    return updateHubMembership(hubId: hubId, action: 'remove', userId: userId);
  }

  static Future<Map<String, dynamic>> leaveHub({
    required int hubId,
  }) {
    return updateHubMembership(hubId: hubId, action: 'leave');
  }

  // ---------------------------------------------------------------------------
  // Session management
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> currentUser({String? accessToken}) async {
    final result = await _authorized(
      (token) => _client.get(
        Uri.parse('$_baseUrl/auth/me/'),
        headers: _headers(token),
      ),
      overrideToken: accessToken,
    );
    await _cacheCurrentUser(result);
    return result;
  }

  /// Exchanges the stored refresh token for a new access token.
  /// Returns false when no refresh token exists or the backend rejects it.
  static Future<bool> refreshSession() async {
    final refreshToken =
        AuthSession.refreshToken ?? await SecureTokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await _postJson(
        '/token/refresh/',
        body: {'refresh': refreshToken},
      );
      final access = response['access'] as String?;
      if (access == null || access.isEmpty) return false;
      await _persistTokens({
        'access': access,
        'refresh': response['refresh'] as String? ?? refreshToken,
      });
      return true;
    } on AuthApiException {
      return false;
    }
  }

  /// Returns true when a stored session can still make authenticated calls.
  static Future<bool> hasValidSession() async {
    final access =
        AuthSession.accessToken ?? await SecureTokenStorage.readAccessToken();
    if (access == null || access.isEmpty) return false;
    AuthSession.accessToken ??= access;
    AuthSession.refreshToken ??= await SecureTokenStorage.readRefreshToken();
    AuthSession.username ??= await SecureTokenStorage.readUsername();
    return true;
  }

  static Future<void> signOut() async {
    await SecureTokenStorage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedCurrentUserKey);
    AuthSession.clear();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Map<String, String> _headers(String? token, {bool includeContentType = true}) {
    final map = <String, String>{
      if (includeContentType) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  static Future<void> _persistTokens(Map<String, dynamic> response) async {
    final access = response['access'] as String?;
    final refresh = response['refresh'] as String?;
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      return;
    }
    final username =
        AuthSession.username ?? await SecureTokenStorage.readUsername() ?? '';
    await SecureTokenStorage.saveTokens(
      accessToken: access,
      refreshToken: refresh,
      username: username,
    );
    AuthSession.setTokens(
      accessToken: access,
      refreshToken: refresh,
      username: username.isEmpty ? null : username,
    );
  }

  static Future<void> _cacheCurrentUser(Map<String, dynamic> response) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedCurrentUserKey, jsonEncode(response));
  }

  static Future<Map<String, dynamic>?> readCachedCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedCurrentUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _authorized(
    Future<http.Response> Function(String? token) send, {
    String? overrideToken,
  }) async {
    var token =
        overrideToken ??
        AuthSession.accessToken ??
        await SecureTokenStorage.readAccessToken();
    try {
      var response = await send(token).timeout(const Duration(seconds: 60));
      if (response.statusCode == 401 && overrideToken == null) {
        if (await refreshSession()) {
          token = AuthSession.accessToken;
          response = await send(token).timeout(const Duration(seconds: 60));
        }
      }
      final decoded = _decodeResponse(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // For list responses, wrap in {"data": [...]} for a uniform return type.
        if (decoded is List) return <String, dynamic>{'data': decoded};
        return decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{'data': decoded};
      }
      throw AuthApiException(
        _extractErrorMessage(decoded) ??
            'Request failed with status ${response.statusCode}',
      );
    } on SocketException {
      throw const AuthApiException(
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      throw const AuthApiException(
        'The request timed out. Please check your connection and try again.',
      );
    } on http.ClientException {
      throw const AuthApiException(
        'Could not connect to the server. Please try again later.',
      );
    } catch (error) {
      if (error is AuthApiException) rethrow;
      throw AuthApiException('Unexpected error: $error');
    }
  }

  static Future<Map<String, dynamic>> _authorizedMultipart(
    Future<http.StreamedResponse> Function(String? token) send, {
    String? overrideToken,
  }) async {
    var token =
        overrideToken ??
        AuthSession.accessToken ??
        await SecureTokenStorage.readAccessToken();
    try {
      var streamed = await send(token).timeout(const Duration(seconds: 60));
      if (streamed.statusCode == 401 && overrideToken == null) {
        if (await refreshSession()) {
          token = AuthSession.accessToken;
          streamed = await send(token).timeout(const Duration(seconds: 60));
        }
      }
      final response = await http.Response.fromStream(streamed);
      final decoded = _decodeResponse(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is List) return <String, dynamic>{'data': decoded};
        return decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{'data': decoded};
      }
      throw AuthApiException(
        _extractErrorMessage(decoded) ??
            'Request failed with status ${response.statusCode}',
      );
    } on SocketException {
      throw const AuthApiException(
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      throw const AuthApiException(
        'The request timed out. Please check your connection and try again.',
      );
    } on http.ClientException {
      throw const AuthApiException(
        'Could not connect to the server. Please try again later.',
      );
    } catch (error) {
      if (error is AuthApiException) rethrow;
      throw AuthApiException('Unexpected error: $error');
    }
  }

  static Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final response = await _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 60));
      final decoded = _decodeResponse(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{'data': decoded};
      }
      throw AuthApiException(
        _extractErrorMessage(decoded) ??
            'Request failed with status ${response.statusCode}',
      );
    } on SocketException {
      throw const AuthApiException(
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      throw const AuthApiException(
        'The request timed out. Please check your connection and try again.',
      );
    } on http.ClientException {
      throw const AuthApiException(
        'Could not connect to the server. Please try again later.',
      );
    } catch (error) {
      if (error is AuthApiException) rethrow;
      throw AuthApiException('Unexpected error: $error');
    }
  }

  static dynamic _decodeResponse(http.Response response) {
    if (response.body.isEmpty) return const <String, dynamic>{};
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {'message': response.body};
    }
  }

  static String? _extractErrorMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      for (final key in ['error', 'message', 'detail']) {
        final v = decoded[key];
        if (v is String && v.isNotEmpty) return v;
      }
      for (final value in decoded.values) {
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String && first.isNotEmpty) return first;
        }
      }
    }
    return null;
  }


  // ---------------------------------------------------------------------------
  // Invites & Notifications & More
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getHubInvite({required int hubId}) async {
    return _authorized((token) => _client.get(Uri.parse('$_baseUrl/hubs/$hubId/invites/'), headers: _headers(token)));
  }

  static Future<Map<String, dynamic>> createHubInvite({required int hubId}) async {
    return _authorized((token) => _client.post(Uri.parse('$_baseUrl/hubs/$hubId/invites/'), headers: _headers(token)));
  }

  static Future<void> revokeHubInvite({required int hubId}) async {
    await _authorized((token) => _client.delete(Uri.parse('$_baseUrl/hubs/$hubId/invites/'), headers: _headers(token)));
  }

  static Future<Map<String, dynamic>> joinHubWithInviteCode({required String code}) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/hub-invites/join/'),
        headers: _headers(token),
        body: jsonEncode({'code': code.trim().toUpperCase()}),
      ),
    );
  }

  static Future<void> registerDeviceToken({required String token}) async {
    await _authorized(
      (authToken) => _client.post(
        Uri.parse('$_baseUrl/devices/register/'),
        headers: _headers(authToken),
        body: jsonEncode({'token': token}),
      ),
    );
  }

  static Future<List<dynamic>> getNotifications() async {
    final response = await _authorized((token) => _client.get(Uri.parse('$_baseUrl/notifications/'), headers: _headers(token)));
    return response as List<dynamic>;
  }

  static Future<void> markNotificationsAsRead({required List<int> notificationIds}) async {
    await _authorized(
      (token) => _client.patch(
        Uri.parse('$_baseUrl/notifications/read-status/'),
        headers: _headers(token),
        body: jsonEncode({'notification_ids': notificationIds}),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Missing Meeting Methods
  // ---------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getMeetings({
    int? hubId,
  }) async {
    final uri = Uri.parse('$_baseUrl/meetings/').replace(
      queryParameters: hubId != null ? {'hub': '$hubId'} : null,
    );
    final result = await _authorized(
      (token) => _client.get(uri, headers: _headers(token)),
    );
    final list = result['data'] ?? result['results'] ?? result;
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  static Future<Map<String, dynamic>> getHubMeetings({
    required int hubId,
    int page = 1,
  }) async {
    final uri = Uri.parse('$_baseUrl/hubs/$hubId/meetings/').replace(
      queryParameters: {'page': '$page'},
    );
    return _authorized(
      (token) => _client.get(uri, headers: _headers(token)),
    );
  }

  static Future<Map<String, dynamic>> createHubMeeting({
    required int hubId,
    required String title,
    String? description,
    String? meetingUrl,
    required String scheduledFor,
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/hubs/$hubId/meetings/'),
        headers: _headers(token),
        body: jsonEncode({
          'title': title,
          'scheduled_for': scheduledFor,
          if (description != null) 'description': description,
          if (meetingUrl != null) 'meeting_url': meetingUrl,
        }),
      ),
    );
  }

  static Future<Map<String, dynamic>> getDirectMessagesPage({
    required int conversationId,
    int page = 1,
  }) async {
    final uri = Uri.parse('$_baseUrl/conversations/direct/$conversationId/messages/')
        .replace(queryParameters: {'page': '$page'});
    return _authorized(
      (token) => _client.get(uri, headers: _headers(token)),
    );
  }

  static Future<Map<String, dynamic>> sendDirectMessage({
    required int conversationId,
    required String content,
    List<PlatformFile>? attachments,
  }) async {
    final needsMultipart = attachments != null && attachments.isNotEmpty;
    final body = <String, dynamic>{'content': content};

    if (!needsMultipart) {
      return _authorized(
        (token) => _client.post(
          Uri.parse('$_baseUrl/conversations/$conversationId/messages/'),
          headers: _headers(token),
          body: jsonEncode(body),
        ),
      );
    }

    return _authorizedMultipart(
      (token) async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/conversations/$conversationId/messages/'),
        );
        request.headers.addAll(_headers(token, includeContentType: false));
        request.fields.addAll(
          body.map((key, value) => MapEntry(key, value.toString())),
        );
        for (final file in attachments) {
          if (file.path != null) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'attachments',
                file.path!,
                filename: file.name,
              ),
            );
          }
        }
        return request.send();
      },
    );
  }

  static Future<Map<String, dynamic>> updateHubMeeting({
    required int meetingId,
    String? title,
    String? description,
    String? meetingUrl,
    String? scheduledFor,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (scheduledFor != null) body['scheduled_for'] = scheduledFor;
    if (description != null) body['description'] = description;
    if (meetingUrl != null) body['meeting_url'] = meetingUrl;
    return _authorized(
      (token) => _client.patch(
        Uri.parse('$_baseUrl/meetings/$meetingId/'),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
  }

  static Future<Map<String, dynamic>> deleteHubMeeting({
    required int meetingId,
  }) async {
    return _authorized((token) => _client.delete(Uri.parse('$_baseUrl/meetings/$meetingId/'), headers: _headers(token)));
  }

  static Future<Map<String, dynamic>> initializeSmsTopUp({
    required int hubId,
    required String bundle,
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/hubs/$hubId/sms-topup/initialize/'),
        headers: _headers(token),
        body: jsonEncode({'bundle': bundle}),
      ),
    );
  }

  static Future<Map<String, dynamic>> verifySmsTopUp({
    required int hubId,
    required String reference,
  }) async {
    return _authorized(
      (token) => _client.post(
        Uri.parse('$_baseUrl/hubs/$hubId/verify_topup/'),
        headers: _headers(token),
        body: jsonEncode({'reference': reference}),
      ),
    );
  }
}
