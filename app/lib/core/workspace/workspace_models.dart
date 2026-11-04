class Workspace {
  const Workspace({required this.id, required this.name, required this.slug, this.myRole});

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    myRole: json['myRole'] as String?,
  );

  final String id;
  final String name;
  final String slug;

  /// The signed-in user's role here (OWNER/ADMIN/MANAGER/STAFF/...). Only
  /// decides which controls are shown; the server enforces every permission.
  final String? myRole;

  bool get canManage => myRole == 'OWNER' || myRole == 'ADMIN';
}

sealed class WorkspaceState {
  const WorkspaceState();
}

class WorkspaceLoading extends WorkspaceState {
  const WorkspaceLoading();
}

class WorkspaceNoneExist extends WorkspaceState {
  const WorkspaceNoneExist({this.errorMessage});
  final String? errorMessage;
}

class WorkspaceSelected extends WorkspaceState {
  const WorkspaceSelected(this.workspace, this.all);
  final Workspace workspace;
  final List<Workspace> all;
}
