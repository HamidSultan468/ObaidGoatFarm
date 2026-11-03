import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'workspace_models.dart';
import 'workspace_repository.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => WorkspaceRepository(ref.watch(apiClientProvider)),
);

final workspaceControllerProvider = NotifierProvider<WorkspaceController, WorkspaceState>(
  WorkspaceController.new,
);

/// Loads the caller's workspaces right after authentication and keeps the
/// first one selected. Multi-workspace switching exists in the backend
/// (`GET /workspaces` returns all of them) but there's no switcher UI yet —
/// see FEATURES.md.
class WorkspaceController extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() {
    final authState = ref.watch(authControllerProvider);
    if (authState is AuthAuthenticated) {
      _load();
    }
    return const WorkspaceLoading();
  }

  WorkspaceRepository get _repository => ref.read(workspaceRepositoryProvider);

  Future<void> _load() async {
    try {
      final workspaces = await _repository.listMine();
      state = workspaces.isEmpty ? const WorkspaceNoneExist() : WorkspaceSelected(workspaces.first, workspaces);
    } on DioException {
      state = const WorkspaceNoneExist(errorMessage: 'Could not load workspaces. Check your connection and try again.');
    }
  }

  Future<bool> create(String name) async {
    state = const WorkspaceLoading();
    try {
      final workspace = await _repository.create(name: name);
      final all = await _repository.listMine();
      state = WorkspaceSelected(workspace, all);
      return true;
    } on DioException catch (error) {
      state = WorkspaceNoneExist(errorMessage: _messageFor(error));
      return false;
    }
  }

  void select(Workspace workspace) {
    final current = state;
    if (current is WorkspaceSelected) {
      state = WorkspaceSelected(workspace, current.all);
    }
  }

  String _messageFor(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Could not create the workspace. Please try again.';
  }
}
