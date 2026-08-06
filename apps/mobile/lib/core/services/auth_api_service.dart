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

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    final response = await _postJson(
      '/auth/register/',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
      },
    );
    return response;
  }

  /// Verifying the OTP also signs the user in — the backend returns a token
  /// pair so profile setup can run without a separate login round trip.
  static Future<Map<String, dynamic>> verifyOtp({
    required String username,
    required String otpCode,
  }) async {
    final response = await _postJson(
      '/auth/verify-otp/',
      body: {'username': username, 'otp_code': otpCode},
    );
    await _persistTokens(response, username: username);
    return response;
  }

  static Future<Map<String, dynamic>> resendOtp({
    required String username,
  }) async {
    return _postJson('/auth/resend-otp/', body: {'username': username});
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _postJson(
      '/token/',
      body: {'username': username, 'password': password},
    );
    await _persistTokens(response, username: username);
    return response;
  }

  static Future<Map<String, dynamic>> currentUser({String? accessToken}) async {
    return _authorized(
      (token) => _client.get(
        Uri.parse('$_baseUrl/auth/me/'),
        headers: _headers(token),
      ),
      overrideToken: accessToken,
    );
  }

  static Future<Map<String, dynamic>> profileSetup({
    String? displayName,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;

    return _authorized(
      (token) => _client.patch(
        Uri.parse('$_baseUrl/auth/profile-setup/'),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
  }

  /// Exchanges the stored refresh token for a new access token.
  /// Returns false when no refresh token exists or the backend rejects it,
  /// which callers should treat as "session over, send the user to login".
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
      // ROTATE_REFRESH_TOKENS is on, so a new refresh token comes back too.
      await _persistTokens({
        'access': access,
        'refresh': response['refresh'] as String? ?? refreshToken,
      });
      return true;
    } on AuthApiException {
      return false;
    }
  }

  /// True when a stored session can still make authenticated calls, refreshing
  /// a stale access token first if needed.
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

  static Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  static Future<void> _persistTokens(
    Map<String, dynamic> response, {
    String? username,
  }) async {
    final access = response['access'] as String?;
    final refresh = response['refresh'] as String?;
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      return;
    }
    final resolvedUsername =
        username ??
        AuthSession.username ??
        await SecureTokenStorage.readUsername() ??
        '';
    await SecureTokenStorage.saveTokens(
      accessToken: access,
      refreshToken: refresh,
      username: resolvedUsername,
    );
    AuthSession.setTokens(
      accessToken: access,
      refreshToken: refresh,
      username: resolvedUsername.isEmpty ? null : resolvedUsername,
    );
  }

  /// Runs an authenticated request, and on a 401 refreshes the access token
  /// once and replays it. Without this every call fails silently as soon as
  /// the access token expires.
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
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return <String, dynamic>{'data': decoded};
      }

      final message =
          _extractErrorMessage(decoded) ??
          'Request failed with status ${response.statusCode}';
      throw AuthApiException(message);
    } on http.ClientException catch (error) {
      throw AuthApiException(
        'Unable to reach the backend at $_baseUrl. ${error.message}',
      );
    } catch (error) {
      if (error is AuthApiException) {
        rethrow;
      }
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
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return <String, dynamic>{'data': decoded};
      }

      final message =
          _extractErrorMessage(decoded) ??
          'Request failed with status ${response.statusCode}';
      throw AuthApiException(message);
    } on http.ClientException catch (error) {
      throw AuthApiException(
        'Unable to reach the backend at $_baseUrl. ${error.message}',
      );
    } catch (error) {
      if (error is AuthApiException) {
        rethrow;
      }
      throw AuthApiException('Unexpected auth error: $error');
    }
  }

  static dynamic _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {'message': response.body};
    }
  }

  static String? _extractErrorMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
      final message = decoded['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      for (final value in decoded.values) {
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String && first.isNotEmpty) {
            return first;
          }
        }
      }
    }
    return null;
  }
}
