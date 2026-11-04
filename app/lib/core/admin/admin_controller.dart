import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import 'admin_models.dart';
import 'admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);

final adminWorkspacesControllerProvider =
    AsyncNotifierProvider<AdminWorkspacesController, List<AdminWorkspace>>(AdminWorkspacesController.new);

class AdminWorkspacesController extends AsyncNotifier<List<AdminWorkspace>> {
  @override
  Future<List<AdminWorkspace>> build() => ref.read(adminRepositoryProvider).listWorkspaces();

  Future<void> setActive(String workspaceId, bool isActive) async {
    await ref.read(adminRepositoryProvider).setWorkspaceActive(workspaceId, isActive);
    ref.invalidateSelf();
    await future;
  }
}

final adminUsersControllerProvider = AsyncNotifierProvider<AdminUsersController, List<AdminUser>>(
  AdminUsersController.new,
);

class AdminUsersController extends AsyncNotifier<List<AdminUser>> {
  @override
  Future<List<AdminUser>> build() => ref.read(adminRepositoryProvider).listUsers();

  Future<void> setActive(String userId, bool isActive) async {
    await ref.read(adminRepositoryProvider).setUserActive(userId, isActive);
    ref.invalidateSelf();
    await future;
  }

  Future<void> setGlobalRole(String userId, String globalRole) async {
    await ref.read(adminRepositoryProvider).setUserGlobalRole(userId, globalRole);
    ref.invalidateSelf();
    await future;
  }
}
