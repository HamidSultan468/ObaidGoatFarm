import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accounting/accounting_controller.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';

class WhatsAppConfigInfo {
  const WhatsAppConfigInfo({required this.configured, this.phoneNumberId, this.displayPhone, this.verifyToken, this.isEnabled = false, this.webhookPath});
  final bool configured;
  final String? phoneNumberId;
  final String? displayPhone;
  final String? verifyToken;
  final bool isEnabled;
  final String? webhookPath;

  factory WhatsAppConfigInfo.fromJson(Map<String, dynamic> json) => WhatsAppConfigInfo(
    configured: json['configured'] as bool,
    phoneNumberId: json['phoneNumberId'] as String?,
    displayPhone: json['displayPhone'] as String?,
    verifyToken: json['verifyToken'] as String?,
    isEnabled: json['isEnabled'] as bool? ?? false,
    webhookPath: json['webhookPath'] as String?,
  );
}

class MyWhatsAppLink {
  const MyWhatsAppLink({required this.phoneE164, required this.verified});
  final String phoneE164;
  final bool verified;
}

class LinkStart {
  const LinkStart({required this.code, required this.instructions});
  final String code;
  final String instructions;
}

class WhatsAppMessage {
  const WhatsAppMessage({required this.direction, required this.phoneE164, required this.status, required this.createdAt, this.body, this.error});
  final String direction;
  final String phoneE164;
  final String status;
  final String? body;
  final String? error;
  final DateTime createdAt;

  factory WhatsAppMessage.fromJson(Map<String, dynamic> json) => WhatsAppMessage(
    direction: json['direction'] as String,
    phoneE164: json['phoneE164'] as String,
    status: json['status'] as String,
    body: json['body'] as String?,
    error: json['error'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class WhatsAppRepository {
  WhatsAppRepository(this._apiClient);
  final ApiClient _apiClient;
  String _ws(String ws) => '/workspaces/$ws/whatsapp';

  Future<WhatsAppConfigInfo> config(String ws) async =>
      WhatsAppConfigInfo.fromJson((await _apiClient.raw.get('${_ws(ws)}/config')).data as Map<String, dynamic>);

  Future<void> saveConfig(String ws, Map<String, dynamic> body) => _apiClient.raw.put('${_ws(ws)}/config', data: body);

  Future<void> removeConfig(String ws) => _apiClient.raw.delete('${_ws(ws)}/config');

  Future<MyWhatsAppLink?> myLink(String ws) async {
    final data = (await _apiClient.raw.get('${_ws(ws)}/my-link')).data;
    if (data is! Map<String, dynamic>) return null;
    return MyWhatsAppLink(phoneE164: data['phoneE164'] as String, verified: data['verified'] as bool);
  }

  Future<LinkStart> startLink(String ws, String phone) async {
    final data = (await _apiClient.raw.post('${_ws(ws)}/my-link', data: {'phone': phone})).data as Map<String, dynamic>;
    return LinkStart(code: data['code'] as String, instructions: data['instructions'] as String);
  }

  Future<void> unlink(String ws) => _apiClient.raw.delete('${_ws(ws)}/my-link');

  Future<List<WhatsAppMessage>> messages(String ws) async =>
      ((await _apiClient.raw.get('${_ws(ws)}/messages')).data as List).map((j) => WhatsAppMessage.fromJson(j as Map<String, dynamic>)).toList();
}

final whatsAppRepositoryProvider = Provider<WhatsAppRepository>((ref) => WhatsAppRepository(ref.watch(apiClientProvider)));

final whatsAppConfigProvider = FutureProvider<WhatsAppConfigInfo>((ref) {
  return ref.read(whatsAppRepositoryProvider).config(requireWorkspaceId(ref));
});

final myWhatsAppLinkProvider = FutureProvider<MyWhatsAppLink?>((ref) {
  return ref.read(whatsAppRepositoryProvider).myLink(requireWorkspaceId(ref));
});
