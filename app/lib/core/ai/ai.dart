import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accounting/accounting_controller.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';

/// Claude models offered in settings (the server accepts any `claude-*` id).
const aiModelChoices = {
  'claude-opus-5-5': 'Claude Opus 5.5 (most capable)',
  'claude-sonnet-5-5': 'Claude Sonnet 5.5 (faster, lower cost)',
  'claude-haiku-5-5': 'Claude Haiku 5.5 (fastest, lowest cost)',
};

class RecordDraft {
  const RecordDraft({
    required this.id,
    required this.source,
    required this.kind,
    required this.status,
    required this.summary,
    required this.payload,
    required this.warnings,
    required this.createdAt,
    this.rawInput,
    this.sourcePhone,
    this.rejectReason,
    this.resultType,
  });

  final String id;
  final String source;
  final String kind;
  final String status;
  final String summary;
  final Map<String, dynamic> payload;
  final List<String> warnings;
  final DateTime createdAt;
  final String? rawInput;
  final String? sourcePhone;
  final String? rejectReason;
  final String? resultType;

  bool get isPending => status == 'PENDING';

  factory RecordDraft.fromJson(Map<String, dynamic> json) => RecordDraft(
    id: json['id'] as String,
    source: json['source'] as String,
    kind: json['kind'] as String,
    status: json['status'] as String,
    summary: json['summary'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    warnings: ((json['warnings'] as List?) ?? const []).cast<String>(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    rawInput: json['rawInput'] as String?,
    sourcePhone: json['sourcePhone'] as String?,
    rejectReason: json['rejectReason'] as String?,
    resultType: json['resultType'] as String?,
  );
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.model,
    required this.keyHint,
    required this.priority,
    required this.isEnabled,
    this.monthlyRequestLimit,
  });

  final String id;
  final String model;
  final String keyHint;
  final int priority;
  final bool isEnabled;
  final int? monthlyRequestLimit;

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) => AiProviderConfig(
    id: json['id'] as String,
    model: json['model'] as String,
    keyHint: json['keyHint'] as String,
    priority: json['priority'] as int,
    isEnabled: json['isEnabled'] as bool,
    monthlyRequestLimit: json['monthlyRequestLimit'] as int?,
  );
}

class AiUsage {
  const AiUsage({required this.configId, required this.requests, required this.failures, required this.inputTokens, required this.outputTokens});
  final String configId;
  final int requests;
  final int failures;
  final int inputTokens;
  final int outputTokens;

  factory AiUsage.fromJson(Map<String, dynamic> json) => AiUsage(
    configId: json['configId'] as String,
    requests: json['requests'] as int,
    failures: json['failures'] as int,
    inputTokens: json['inputTokens'] as int,
    outputTokens: json['outputTokens'] as int,
  );
}

class AiRepository {
  AiRepository(this._apiClient);
  final ApiClient _apiClient;

  String _ws(String ws) => '/workspaces/$ws';

  Future<RecordDraft> draftFromText(String ws, String text) async {
    final response = await _apiClient.raw.post('${_ws(ws)}/drafts/from-text', data: {'text': text});
    return RecordDraft.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RecordDraft> draftFromReceipt(String ws, String attachmentId, {String? note}) async {
    final response = await _apiClient.raw.post(
      '${_ws(ws)}/drafts/from-receipt',
      data: {'attachmentId': attachmentId, if (note != null && note.isNotEmpty) 'note': note},
    );
    return RecordDraft.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<RecordDraft>> drafts(String ws, String status) async {
    final response = await _apiClient.raw.get('${_ws(ws)}/drafts', queryParameters: {'status': status});
    return (response.data as List).map((j) => RecordDraft.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> approve(String ws, String id, Map<String, dynamic> payload) =>
      _apiClient.raw.post('${_ws(ws)}/drafts/$id/approve', data: {'payload': payload});

  Future<void> reject(String ws, String id, {String? reason}) =>
      _apiClient.raw.post('${_ws(ws)}/drafts/$id/reject', data: {if (reason != null && reason.isNotEmpty) 'reason': reason});

  Future<List<AiProviderConfig>> providers(String ws) async {
    final response = await _apiClient.raw.get('${_ws(ws)}/ai/providers');
    return (response.data as List).map((j) => AiProviderConfig.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> addProvider(String ws, {required String apiKey, required String model, int priority = 1, int? monthlyRequestLimit}) =>
      _apiClient.raw.post('${_ws(ws)}/ai/providers', data: {'apiKey': apiKey, 'model': model, 'priority': priority, 'monthlyRequestLimit': ?monthlyRequestLimit});

  Future<void> updateProvider(String ws, String id, Map<String, dynamic> changes) => _apiClient.raw.patch('${_ws(ws)}/ai/providers/$id', data: changes);

  Future<void> removeProvider(String ws, String id) => _apiClient.raw.delete('${_ws(ws)}/ai/providers/$id');

  Future<(bool, String)> testProvider(String ws, String id) async {
    final response = await _apiClient.raw.post('${_ws(ws)}/ai/providers/$id/test');
    final data = response.data as Map<String, dynamic>;
    return (data['ok'] as bool, data['message'] as String);
  }

  Future<List<AiUsage>> usage(String ws) async {
    final response = await _apiClient.raw.get('${_ws(ws)}/ai/providers/usage');
    return ((response.data as Map<String, dynamic>)['providers'] as List).map((j) => AiUsage.fromJson(j as Map<String, dynamic>)).toList();
  }
}

final aiRepositoryProvider = Provider<AiRepository>((ref) => AiRepository(ref.watch(apiClientProvider)));

final draftsProvider = FutureProvider.family<List<RecordDraft>, String>((ref, status) {
  return ref.read(aiRepositoryProvider).drafts(requireWorkspaceId(ref), status);
});

final aiProvidersProvider = FutureProvider<List<AiProviderConfig>>((ref) {
  return ref.read(aiRepositoryProvider).providers(requireWorkspaceId(ref));
});

final aiUsageProvider = FutureProvider<List<AiUsage>>((ref) {
  return ref.read(aiRepositoryProvider).usage(requireWorkspaceId(ref));
});

void refreshDrafts(WidgetRef ref) => ref.invalidate(draftsProvider);
