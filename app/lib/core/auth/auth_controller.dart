import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession();
    return const AuthInitial();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> _restoreSession() async {
    final hasSession = await _repository.hasActiveSession();
    if (!hasSession) {
      state = const AuthUnauthenticated();
      return;
    }

    state = const AuthLoading();
    try {
      final profile = await _repository.fetchCurrentProfile();
      state = AuthAuthenticated(profile);
    } on DioException {
      // Stored token is expired/invalid and the ApiClient's refresh
      // interceptor couldn't recover it — fall back to a clean login.
      await _repository.logout();
      state = const AuthUnauthenticated();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final result = await _repository.login(email: email, password: password);
      switch (result) {
        case LoginSucceeded(:final profile):
          state = AuthAuthenticated(profile);
          return true;
        case LoginNeedsMfa(:final mfaToken):
          state = AuthMfaRequired(mfaToken);
          return true;
      }
    } on DioException catch (error) {
      state = AuthUnauthenticated(errorMessage: _messageFor(error));
      return false;
    }
  }

  Future<bool> completeMfaLogin(String code) async {
    final current = state;
    if (current is! AuthMfaRequired) return false;

    state = const AuthLoading();
    try {
      final profile = await _repository.completeMfaLogin(mfaToken: current.mfaToken, code: code);
      state = AuthAuthenticated(profile);
      return true;
    } on DioException catch (error) {
      state = AuthMfaRequired(current.mfaToken, errorMessage: _messageFor(error));
      return false;
    }
  }

  void cancelMfaChallenge() {
    state = const AuthUnauthenticated();
  }

  /// Re-fetches the profile without disturbing the UI with a loading state
  /// — used after an in-place account change (e.g. MFA enabled/disabled)
  /// where the user is already looking at an authenticated screen.
  Future<void> refreshProfile() async {
    if (state is! AuthAuthenticated) return;
    try {
      state = AuthAuthenticated(await _repository.fetchCurrentProfile());
    } on DioException {
      // Leave the stale profile in place rather than booting the user out
      // for a transient network error.
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthUnauthenticated();
  }

  String _messageFor(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return 'Login failed. Please try again.';
  }
}
