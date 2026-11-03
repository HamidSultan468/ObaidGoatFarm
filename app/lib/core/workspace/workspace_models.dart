class Workspace {
  const Workspace({required this.id, required this.name, required this.slug});

  factory Workspace.fromJson(Map<String, dynamic> json) =>
      Workspace(id: json['id'] as String, name: json['name'] as String, slug: json['slug'] as String);

  final String id;
  final String name;
  final String slug;
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
