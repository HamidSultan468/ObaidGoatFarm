import '../api/api_client.dart';
import 'workspace_models.dart';

class WorkspaceRepository {
  WorkspaceRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Workspace>> listMine() async {
    final response = await _apiClient.raw.get('/workspaces');
    return (response.data as List).map((json) => Workspace.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Workspace> create({required String name}) async {
    final response = await _apiClient.raw.post('/workspaces', data: {'name': name});
    return Workspace.fromJson(response.data as Map<String, dynamic>);
  }

  /// `role` is one of ADMIN/MANAGER/STAFF/VIEWER — enforced server-side; a
  /// caller without OWNER/ADMIN in this workspace will get a real 403.
  Future<void> inviteMember({required String workspaceId, required String email, required String role}) async {
    await _apiClient.raw.post('/workspaces/$workspaceId/members', data: {'email': email, 'role': role});
  }
}
