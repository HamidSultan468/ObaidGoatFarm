class MfaSetup {
  const MfaSetup({required this.secret, required this.otpauthUrl});

  factory MfaSetup.fromJson(Map<String, dynamic> json) =>
      MfaSetup(secret: json['secret'] as String, otpauthUrl: json['otpauthUrl'] as String);

  final String secret;
  final String otpauthUrl;
}

class AuthSession {
  const AuthSession({required this.id, required this.deviceId, required this.createdAt, required this.expiresAt, this.deviceName, this.platform});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    id: json['id'] as String,
    deviceId: json['deviceId'] as String?,
    deviceName: json['deviceName'] as String?,
    platform: json['platform'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );

  final String id;
  final String? deviceId;
  /// Friendly name/platform the client reported at login — null for a
  /// session from before this existed, or a client that didn't send it.
  final String? deviceName;
  final String? platform;
  final DateTime createdAt;
  final DateTime expiresAt;
}
