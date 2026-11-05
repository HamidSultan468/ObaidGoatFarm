import '../api/api_client.dart';
import 'admin_models.dart';

class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AdminWorkspace>> listWorkspaces() async {
    final response = await _apiClient.raw.get('/admin/workspaces');
    return (response.data as List).map((json) => AdminWorkspace.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> setWorkspaceActive(String workspaceId, bool isActive) async {
    await _apiClient.raw.patch('/admin/workspaces/$workspaceId/status', data: {'isActive': isActive});
  }

  Future<List<AdminUser>> listUsers() async {
    final response = await _apiClient.raw.get('/admin/users');
    return (response.data as List).map((json) => AdminUser.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> setUserActive(String userId, bool isActive) async {
    await _apiClient.raw.patch('/admin/users/$userId/status', data: {'isActive': isActive});
  }

  Future<void> setUserGlobalRole(String userId, String globalRole) async {
    await _apiClient.raw.patch('/admin/users/$userId/global-role', data: {'globalRole': globalRole});
  }

  Future<List<SystemLogEntry>> listLogs({String? action}) async {
    final response = await _apiClient.raw.get('/admin/logs', queryParameters: {'limit': 200, if (action != null && action.isNotEmpty) 'action': action});
    return (response.data as List).map((json) => SystemLogEntry.fromJson(json as Map<String, dynamic>)).toList();
  }
}
