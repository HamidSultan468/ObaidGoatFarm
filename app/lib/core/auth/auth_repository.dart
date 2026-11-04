import 'package:dio/dio.dart';
import '../api/api_client.dart';
import 'auth_models.dart';
import 'mfa_models.dart';

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<LoginAttemptResult> login({required String email, required String password}) async {
    final response = await _apiClient.raw.post('/auth/login', data: {'email': email, 'password': password});
    final data = response.data as Map<String, dynamic>;

    if (data['mfaRequired'] == true) {
      return LoginNeedsMfa(data['mfaToken'] as String);
    }

    await _apiClient.saveTokens(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
    return LoginSucceeded(UserProfile.fromJson(data['profile'] as Map<String, dynamic>));
  }

  Future<UserProfile> completeMfaLogin({required String mfaToken, required String code}) async {
    final response = await _apiClient.raw.post('/auth/mfa/login', data: {'mfaToken': mfaToken, 'code': code});
    final data = response.data as Map<String, dynamic>;

    await _apiClient.saveTokens(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String preferredLanguage = 'en',
  }) async {
    await _apiClient.raw.post(
      '/auth/register',
      data: {'email': email, 'password': password, 'fullName': fullName, 'preferredLanguage': preferredLanguage},
    );
  }

  Future<UserProfile> fetchCurrentProfile() async {
    final response = await _apiClient.raw.get('/auth/me');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final refreshToken = await _apiClient.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _apiClient.raw.post('/auth/logout', data: {'refreshToken': refreshToken});
      } on DioException {
        // Best-effort server-side revocation; local tokens are cleared regardless.
      }
    }
    await _apiClient.clearTokens();
  }

  Future<bool> hasActiveSession() => _apiClient.hasSession();

  // --- MFA management (for an already-authenticated user) ---

  Future<MfaSetup> beginMfaSetup() async {
    final response = await _apiClient.raw.post('/auth/mfa/setup');
    return MfaSetup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> confirmMfaSetup(String code) async {
    await _apiClient.raw.post('/auth/mfa/verify-setup', data: {'code': code});
  }

  Future<void> disableMfa(String code) async {
    await _apiClient.raw.post('/auth/mfa/disable', data: {'code': code});
  }

  // --- Session management ---

  Future<List<AuthSession>> listSessions() async {
    final response = await _apiClient.raw.get('/auth/sessions');
    return (response.data as List).map((json) => AuthSession.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> revokeSession(String sessionId) async {
    await _apiClient.raw.delete('/auth/sessions/$sessionId');
  }
}
