import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';
import 'mfa_models.dart';

final sessionsControllerProvider = AsyncNotifierProvider<SessionsController, List<AuthSession>>(
  SessionsController.new,
);

class SessionsController extends AsyncNotifier<List<AuthSession>> {
  @override
  Future<List<AuthSession>> build() => ref.read(authRepositoryProvider).listSessions();

  Future<void> revoke(String sessionId) async {
    await ref.read(authRepositoryProvider).revokeSession(sessionId);
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
