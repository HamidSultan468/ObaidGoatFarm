import 'package:dio/dio.dart';
import '../api/api_client.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfile> login({required String email, required String password}) async {
    final response = await _apiClient.raw.post('/auth/login', data: {'email': email, 'password': password});

    await _apiClient.saveTokens(
      accessToken: response.data['accessToken'] as String,
      refreshToken: response.data['refreshToken'] as String,
    );

    return UserProfile.fromJson(response.data['profile'] as Map<String, dynamic>);
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
}
