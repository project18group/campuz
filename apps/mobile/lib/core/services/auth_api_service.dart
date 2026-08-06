import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/services/auth_session.dart';
import 'package:mobile/core/services/secure_token_storage.dart';

class AuthApiException implements Exception {
  final String message;

  const AuthApiException(this.message);

  @override
  String toString() => message;
}

class AuthApiService {
  AuthApiService._();

  static final http.Client _client = http.Client();

  static String get _baseUrl {
    const envBaseUrl = String.fromEnvironment('CAMPUZ_API_BASE_URL');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }
    return "https://campuz-api.onrender.com/api";
  }

  // ---------------------------------------------------------------------------
  // Phone-OTP authentication
  // ---------------------------------------------------------------------------

  /// Requests a 6-digit OTP to be sent to [phoneNumber] via SMS.
  ///
  /// Throws [AuthApiException] on network or server errors.  Returns the raw
  /// response map (contains `message` on success).
  static Future<Map<String, dynamic>> requestOtp({
    required String phoneNumber,
  }) async {
    return _postJson(
      '/auth/request-otp/',
      body: {'phone_number': phoneNumber},
    );
  }

  /// Verifies [otpCode] for [phoneNumber].
  ///
  /// On success the backend returns:
  ///   { "access": "...", "refresh": "...", "is_new_user": true/false }
  ///
  /// Tokens are persisted to secure storage and [AuthSession] automatically.
  /// The caller should read `response['is_new_user']` to decide the next route.
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

  /// Sets the user's public [username], optional [displayName], and optional
  /// [avatarUrl] after OTP sign-in.
  static Future<Map<String, dynamic>> profileSetup({
    required String username,
    String? displayName,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{'username': username};
    if (displayName != null && displayName.isNotEmpty) {
      body['display_name'] = displayName;
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      body['avatar_url'] = avatarUrl;
    }

    return _authorized(
      (token) => _client.patch(
        Uri.parse('$_baseUrl/auth/profile-setup/'),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Session management (unchanged)
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> currentUser({String? accessToken}) async {
    return _authorized(
      (token) => _client.get(
        Uri.parse('$_baseUrl/auth/me/'),
        headers: _headers(token),
      ),
      overrideToken: accessToken,
    );
  }

  /// Exchanges the stored refresh token for a new access token.
  /// Returns false when no refresh token exists or the backend rejects it.
  static Future<bool> refreshSession() async {
    final refreshToken =
        AuthSession.refreshToken ?? await SecureTokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }
    try {
      final response = await _postJson(
        '/token/refresh/',
        body: {'refresh': refreshToken},
      );
      final access = response['access'] as String?;
      if (access == null || access.isEmpty) {
        return false;
      }
      // ROTATE_REFRESH_TOKENS is on — a new refresh token comes back too.
      await _persistTokens({
        'access': access,
        'refresh': response['refresh'] as String? ?? refreshToken,
      });
      return true;
    } on AuthApiException {
      return false;
    }
  }

  /// True when a stored session can still make authenticated calls.
  static Future<bool> hasValidSession() async {
    final access =
        AuthSession.accessToken ?? await SecureTokenStorage.readAccessToken();
    if (access == null || access.isEmpty) {
      return false;
    }
    AuthSession.accessToken ??= access;
    AuthSession.refreshToken ??= await SecureTokenStorage.readRefreshToken();
    AuthSession.username ??= await SecureTokenStorage.readUsername();
    try {
      await currentUser();
      return true;
    } on AuthApiException {
      return false;
    }
  }

  static Future<void> signOut() async {
    await SecureTokenStorage.clear();
    AuthSession.clear();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  static Future<void> _persistTokens(Map<String, dynamic> response) async {
    final access = response['access'] as String?;
    final refresh = response['refresh'] as String?;
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
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

  /// Runs an authenticated request; on 401 refreshes the token once and
  /// replays the call before giving up.
  static Future<Map<String, dynamic>> _authorized(
    Future<http.Response> Function(String? token) send, {
    String? overrideToken,
  }) async {
    var token =
        overrideToken ??
        AuthSession.accessToken ??
        await SecureTokenStorage.readAccessToken();

    try {
      var response = await send(token);

      if (response.statusCode == 401 && overrideToken == null) {
        if (await refreshSession()) {
          token = AuthSession.accessToken;
          response = await send(token);
        }
      }

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
    } on http.ClientException catch (error) {
      throw AuthApiException(
        'Unable to reach the backend at $_baseUrl. ${error.message}',
      );
    } catch (error) {
      if (error is AuthApiException) rethrow;
      throw AuthApiException('Unexpected auth error: $error');
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
      );

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
    } on http.ClientException catch (error) {
      throw AuthApiException(
        'Unable to reach the backend at $_baseUrl. ${error.message}',
      );
    } catch (error) {
      if (error is AuthApiException) rethrow;
      throw AuthApiException('Unexpected auth error: $error');
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
}
