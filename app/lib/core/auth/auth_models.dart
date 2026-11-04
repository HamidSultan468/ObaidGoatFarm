class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.globalRole,
    required this.preferredLanguage,
    required this.mfaEnabled,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String,
    globalRole: json['globalRole'] as String,
    preferredLanguage: json['preferredLanguage'] as String,
    mfaEnabled: json['mfaEnabled'] as bool,
  );

  final String id;
  final String email;
  final String fullName;
  final String globalRole;
  final String preferredLanguage;
  final bool mfaEnabled;
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

/// Password was correct but the account has MFA enabled — a second step
/// (POST /auth/mfa/login with a TOTP code) is required before real session
/// tokens are issued.
class AuthMfaRequired extends AuthState {
  const AuthMfaRequired(this.mfaToken, {this.errorMessage});
  final String mfaToken;
  final String? errorMessage;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.errorMessage});
  final String? errorMessage;
}

/// Result of AuthRepository.login() — either real tokens were issued, or
/// the account needs a second MFA step before they will be.
sealed class LoginAttemptResult {
  const LoginAttemptResult();
}

class LoginSucceeded extends LoginAttemptResult {
  const LoginSucceeded(this.profile);
  final UserProfile profile;
}

class LoginNeedsMfa extends LoginAttemptResult {
  const LoginNeedsMfa(this.mfaToken);
  final String mfaToken;
}
