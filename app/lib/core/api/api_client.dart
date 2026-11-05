import 'package:dio/dio.dart';
import 'device_info.dart';
import 'token_storage.dart';

/// Base URL for the NestJS backend. Overridden at build time with
/// `--dart-define=API_BASE_URL=https://...` for non-local environments.
const String _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

const _accessTokenKey = 'tsm_access_token';
const _refreshTokenKey = 'tsm_refresh_token';

/// Wraps Dio with secure token storage and automatic access-token refresh.
/// This is the only HTTP client the app should use — every feature's data
/// layer goes through it so auth/session handling stays centralized.
class ApiClient {
  ApiClient({TokenStorage? tokenStorage}) : _tokenStorage = tokenStorage ?? SecureTokenStorage() {
    _dio = Dio(BaseOptions(baseUrl: _apiBaseUrl, connectTimeout: const Duration(seconds: 15)));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.read(_accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Only meaningful on /auth/login and /auth/mfa/login (the backend
          // only reads them there, to enrich Settings > Active sessions with
          // a friendly name instead of a bare device id) — sent on every
          // request anyway, same as Authorization, to keep this simple.
          options.headers['X-Device-Id'] = await deviceId(_tokenStorage);
          options.headers['X-Device-Name'] = deviceName();
          options.headers['X-Device-Platform'] = devicePlatform();
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && !_isAuthEndpoint(error.requestOptions.path)) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final retryResponse = await _dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;

  Dio get raw => _dio;

  bool _isAuthEndpoint(String path) =>
      path.contains('/auth/login') || path.contains('/auth/refresh') || path.contains('/auth/register');

  Future<bool> _tryRefresh() async {
    final refreshToken = await _tokenStorage.read(_refreshTokenKey);
    if (refreshToken == null) {
      return false;
    }

    try {
      final response = await _dio.post('/auth/refresh', data: {'refreshToken': refreshToken});
      await saveTokens(
        accessToken: response.data['accessToken'] as String,
        refreshToken: response.data['refreshToken'] as String,
      );
      return true;
    } on DioException {
      await clearTokens();
      return false;
    }
  }

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _tokenStorage.write(_accessTokenKey, accessToken);
    await _tokenStorage.write(_refreshTokenKey, refreshToken);
  }

  Future<void> clearTokens() async {
    await _tokenStorage.delete(_accessTokenKey);
    await _tokenStorage.delete(_refreshTokenKey);
  }

  Future<String?> readRefreshToken() => _tokenStorage.read(_refreshTokenKey);

  Future<bool> hasSession() async => await _tokenStorage.read(_accessTokenKey) != null;
}
