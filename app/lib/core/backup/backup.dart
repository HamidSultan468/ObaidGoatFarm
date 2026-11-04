import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accounting/accounting_controller.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../workspace/workspace_models.dart';

class BackupItem {
  const BackupItem({
    required this.id,
    required this.trigger,
    required this.status,
    required this.startedAt,
    this.sizeBytes,
    this.counts,
    this.error,
    this.completedAt,
  });

  final String id;
  final String trigger;
  final String status;
  final int? sizeBytes;
  final Map<String, int>? counts;
  final String? error;
  final DateTime startedAt;
  final DateTime? completedAt;

  bool get isCompleted => status == 'COMPLETED';

  /// `12 animals · 48 transactions · 3 documents`.
  String get summary {
    final c = counts;
    if (c == null) return '';
    return [
      '${c['animals'] ?? 0} animals',
      '${c['journalEntries'] ?? 0} transactions',
      '${c['landParcels'] ?? 0} land',
      '${c['attachments'] ?? 0} documents',
    ].join(' · ');
  }

  factory BackupItem.fromJson(Map<String, dynamic> json) => BackupItem(
    id: json['id'] as String,
    trigger: json['trigger'] as String,
    status: json['status'] as String,
    sizeBytes: json['sizeBytes'] as int?,
    counts: (json['counts'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)),
    error: json['error'] as String?,
    startedAt: DateTime.parse(json['startedAt'] as String),
    completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
  );
}

class BackupStatus {
  const BackupStatus({
    required this.autoBackupEnabled,
    required this.retention,
    required this.backupCount,
    required this.backupBytes,
    required this.documentBytes,
    this.lastBackup,
    this.lastSuccessfulBackup,
  });

  final bool autoBackupEnabled;
  final int retention;
  final int backupCount;
  final int backupBytes;
  final int documentBytes;
  final BackupItem? lastBackup;
  final BackupItem? lastSuccessfulBackup;

  factory BackupStatus.fromJson(Map<String, dynamic> json) => BackupStatus(
    autoBackupEnabled: json['autoBackupEnabled'] as bool,
    retention: json['retention'] as int,
    backupCount: json['backupCount'] as int,
    backupBytes: json['backupBytes'] as int,
    documentBytes: json['documentBytes'] as int,
    lastBackup: json['lastBackup'] == null ? null : BackupItem.fromJson(json['lastBackup'] as Map<String, dynamic>),
    lastSuccessfulBackup: json['lastSuccessfulBackup'] == null ? null : BackupItem.fromJson(json['lastSuccessfulBackup'] as Map<String, dynamic>),
  );
}

class VerifyResult {
  const VerifyResult({required this.valid, required this.errors});
  final bool valid;
  final List<String> errors;
}

class BackupRepository {
  BackupRepository(this._apiClient);
  final ApiClient _apiClient;

  String _base(String ws) => '/workspaces/$ws/backups';

  Future<List<BackupItem>> list(String ws) async {
    final response = await _apiClient.raw.get(_base(ws));
    return (response.data as List).map((j) => BackupItem.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<BackupStatus> status(String ws) async {
    final response = await _apiClient.raw.get('${_base(ws)}/status');
    return BackupStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BackupItem> create(String ws) async {
    final response = await _apiClient.raw.post(_base(ws));
    return BackupItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateSettings(String ws, {bool? autoBackupEnabled, int? retention}) async {
    await _apiClient.raw.patch('${_base(ws)}/settings', data: {'autoBackupEnabled': ?autoBackupEnabled, 'retention': ?retention});
  }

  Future<VerifyResult> verify(String ws, String id) async {
    final response = await _apiClient.raw.post('${_base(ws)}/$id/verify');
    final data = response.data as Map<String, dynamic>;
    return VerifyResult(valid: data['valid'] as bool, errors: (data['errors'] as List).cast<String>());
  }

  Future<Uint8List> download(String ws, String id) async {
    final response = await _apiClient.raw.get<List<int>>('${_base(ws)}/$id/download', options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(response.data!);
  }

  /// Returns the NEW workspace the backup was restored into.
  Future<Workspace> restore(String ws, String id) async {
    final response = await _apiClient.raw.post('${_base(ws)}/$id/restore');
    return Workspace.fromJson((response.data as Map<String, dynamic>)['workspace'] as Map<String, dynamic>);
  }

  Future<Workspace> restoreFromFile(Uint8List bytes, String fileName) async {
    final response = await _apiClient.raw.post(
      '/backups/restore-file',
      data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: fileName)}),
    );
    return Workspace.fromJson((response.data as Map<String, dynamic>)['workspace'] as Map<String, dynamic>);
  }

  Future<void> delete(String ws, String id) => _apiClient.raw.delete('${_base(ws)}/$id');
}

final backupRepositoryProvider = Provider<BackupRepository>((ref) => BackupRepository(ref.watch(apiClientProvider)));

final backupStatusProvider = FutureProvider<BackupStatus>((ref) {
  return ref.read(backupRepositoryProvider).status(requireWorkspaceId(ref));
});

final backupListProvider = FutureProvider<List<BackupItem>>((ref) {
  return ref.read(backupRepositoryProvider).list(requireWorkspaceId(ref));
});

void refreshBackups(WidgetRef ref) {
  ref.invalidate(backupStatusProvider);
  ref.invalidate(backupListProvider);
}
