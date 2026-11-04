class MfaSetup {
  const MfaSetup({required this.secret, required this.otpauthUrl});

  factory MfaSetup.fromJson(Map<String, dynamic> json) =>
      MfaSetup(secret: json['secret'] as String, otpauthUrl: json['otpauthUrl'] as String);

  final String secret;
  final String otpauthUrl;
}

class AuthSession {
  const AuthSession({required this.id, required this.deviceId, required this.createdAt, required this.expiresAt});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    id: json['id'] as String,
    deviceId: json['deviceId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );

  final String id;
  final String? deviceId;
  final DateTime createdAt;
  final DateTime expiresAt;
}
