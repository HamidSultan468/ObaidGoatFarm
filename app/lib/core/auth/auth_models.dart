class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.globalRole,
    required this.preferredLanguage,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String,
    globalRole: json['globalRole'] as String,
    preferredLanguage: json['preferredLanguage'] as String,
  );

  final String id;
  final String email;
  final String fullName;
  final String globalRole;
  final String preferredLanguage;
}

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.profile);
  final UserProfile profile;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.errorMessage});
  final String? errorMessage;
}
