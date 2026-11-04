class AdminWorkspace {
  const AdminWorkspace({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.memberCount,
  });

  factory AdminWorkspace.fromJson(Map<String, dynamic> json) => AdminWorkspace(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    isActive: json['isActive'] as bool,
    memberCount: (json['_count'] as Map<String, dynamic>)['users'] as int,
  );

  final String id;
  final String name;
  final String slug;
  final bool isActive;
  final int memberCount;
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.globalRole,
    required this.isActive,
    required this.mfaEnabled,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String,
    globalRole: json['globalRole'] as String,
    isActive: json['isActive'] as bool,
    mfaEnabled: json['mfaEnabled'] as bool,
  );

  final String id;
  final String email;
  final String fullName;
  final String globalRole;
  final bool isActive;
  final bool mfaEnabled;
}
