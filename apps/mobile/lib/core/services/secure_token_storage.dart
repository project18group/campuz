import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  SecureTokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'campuz_access_token';
  static const _refreshTokenKey = 'campuz_refresh_token';
  static const _usernameKey = 'campuz_username';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String username,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _usernameKey, value: username);
  }

  static Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  static Future<String?> readUsername() {
    return _storage.read(key: _usernameKey);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _usernameKey);
  }
}
