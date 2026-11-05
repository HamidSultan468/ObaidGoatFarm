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

  /// Mirrors the backend's FINANCE_VIEWERS role set (reports.controller.ts,
  /// analytics.controller.ts) — STAFF/VIEWER get 403 on financial reports,
  /// so the dashboard shouldn't show them a chart/KPIs stuck on an error.
  bool get canViewFinance => myRole == 'OWNER' || myRole == 'ADMIN' || myRole == 'MANAGER';
}

/// One row on the "Staff" tab: an active membership plus the user it belongs to.
class WorkspaceMember {
  const WorkspaceMember({
    required this.id,
    required this.role,
    required this.invitedAt,
    this.acceptedAt,
    required this.userId,
    required this.email,
    this.fullName,
    required this.userIsActive,
    this.lastLoginAt,
  });

  final String id;
  final String role;
  final DateTime invitedAt;
  final DateTime? acceptedAt;
  final String userId;
  final String email;
  final String? fullName;
  final bool userIsActive;
  final DateTime? lastLoginAt;

  String get displayName => fullName?.isNotEmpty == true ? fullName! : email;

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return WorkspaceMember(
      id: json['id'] as String,
      role: json['role'] as String,
      invitedAt: DateTime.parse(json['invitedAt'] as String),
      acceptedAt: json['acceptedAt'] != null ? DateTime.parse(json['acceptedAt'] as String) : null,
      userId: user['id'] as String,
      email: user['email'] as String,
      fullName: user['fullName'] as String?,
      userIsActive: user['isActive'] as bool,
      lastLoginAt: user['lastLoginAt'] != null ? DateTime.parse(user['lastLoginAt'] as String) : null,
    );
  }
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
