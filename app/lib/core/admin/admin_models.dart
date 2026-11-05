class AdminWorkspace {
  const AdminWorkspace({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.memberCount,
    required this.createdAt,
    this.ownerEmail,
    this.ownerName,
    this.roleBreakdown = const {},
    this.animalCount = 0,
    this.landParcelCount = 0,
    this.transactionCount = 0,
  });

  factory AdminWorkspace.fromJson(Map<String, dynamic> json) => AdminWorkspace(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    isActive: json['isActive'] as bool,
    memberCount: json['memberCount'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    ownerEmail: json['ownerEmail'] as String?,
    ownerName: json['ownerName'] as String?,
    roleBreakdown: (json['roleBreakdown'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? const {},
    animalCount: json['animalCount'] as int? ?? 0,
    landParcelCount: json['landParcelCount'] as int? ?? 0,
    transactionCount: json['transactionCount'] as int? ?? 0,
  );

  final String id;
  final String name;
  final String slug;
  final bool isActive;
  final int memberCount;
  final DateTime createdAt;
  final String? ownerEmail;
  final String? ownerName;
  final Map<String, int> roleBreakdown;
  final int animalCount;
  final int landParcelCount;
  final int transactionCount;
}

class AdminUserWorkspace {
  const AdminUserWorkspace({required this.id, required this.name, required this.role});

  factory AdminUserWorkspace.fromJson(Map<String, dynamic> json) =>
      AdminUserWorkspace(id: json['id'] as String, name: json['name'] as String, role: json['role'] as String);

  final String id;
  final String name;
  final String role;
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.globalRole,
    required this.isActive,
    required this.mfaEnabled,
    required this.createdAt,
    this.lastLoginAt,
    this.preferredLanguage = 'en',
    this.workspaces = const [],
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String,
    globalRole: json['globalRole'] as String,
    isActive: json['isActive'] as bool,
    mfaEnabled: json['mfaEnabled'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastLoginAt: json['lastLoginAt'] != null ? DateTime.parse(json['lastLoginAt'] as String) : null,
    preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
    workspaces: ((json['workspaces'] as List?) ?? const [])
        .map((w) => AdminUserWorkspace.fromJson(w as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String email;
  final String fullName;
  final String globalRole;
  final bool isActive;
  final bool mfaEnabled;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String preferredLanguage;
  final List<AdminUserWorkspace> workspaces;
}

class SystemLogEntry {
  const SystemLogEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.createdAt,
    this.entityId,
    this.workspaceName,
    this.actorEmail,
    this.ipAddress,
  });

  factory SystemLogEntry.fromJson(Map<String, dynamic> json) => SystemLogEntry(
    id: json['id'] as String,
    action: json['action'] as String,
    entityType: json['entityType'] as String,
    entityId: json['entityId'] as String?,
    workspaceName: (json['workspace'] as Map<String, dynamic>?)?['name'] as String?,
    actorEmail: (json['user'] as Map<String, dynamic>?)?['email'] as String?,
    ipAddress: json['ipAddress'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String id;
  final String action;
  final String entityType;
  final String? entityId;
  /// Null for a platform-level action with no workspace (e.g. admin console mutations).
  final String? workspaceName;
  /// Null for a system-triggered action with no human actor (e.g. the daily backup scheduler).
  final String? actorEmail;
  final String? ipAddress;
  final DateTime createdAt;
}
