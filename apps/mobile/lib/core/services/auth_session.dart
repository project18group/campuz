class AuthSession {
  AuthSession._();

  static String? accessToken;
  static String? refreshToken;
  static String? username;

  static void setTokens({
    required String accessToken,
    required String refreshToken,
    String? username,
  }) {
    AuthSession.accessToken = accessToken;
    AuthSession.refreshToken = refreshToken;
    AuthSession.username = username;
  }

  static void clear() {
    accessToken = null;
    refreshToken = null;
    username = null;
  }
}
