import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accounting/accounting_controller.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';

/// Must match the backend's MAX_UPLOAD_BYTES; checked client-side first so
/// a too-large file fails fast without uploading 10+ MB.
const maxUploadBytes = 10 * 1024 * 1024;
const allowedDocumentExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];

class Attachment {
  const Attachment({
    required this.id,
    required this.module,
    required this.title,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    this.recordId,
  });

  final String id;
  final String module;
  final String? recordId;
  final String title;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  bool get isImage => mimeType.startsWith('image/');

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    id: json['id'] as String,
    module: json['module'] as String,
    recordId: json['recordId'] as String?,
    title: json['title'] as String,
    fileName: json['fileName'] as String,
    mimeType: json['mimeType'] as String,
    sizeBytes: json['sizeBytes'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// `1.2 MB`, `340 KB`, `512 B`. Integer arithmetic only.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes + 512) ~/ 1024} KB';
  final tenths = (bytes * 10 + 512 * 1024) ~/ (1024 * 1024);
  return '${tenths ~/ 10}.${tenths % 10} MB';
}

class DocumentsRepository {
  DocumentsRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<Attachment>> list(String workspaceId, {String? module, String? recordId, String? search}) async {
    final response = await _apiClient.raw.get(
      '/workspaces/$workspaceId/attachments',
      queryParameters: {'module': ?module, 'recordId': ?recordId, if (search != null && search.isNotEmpty) 'search': search},
    );
    return (response.data as List).map((json) => Attachment.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Attachment> upload(
    String workspaceId, {
    required String module,
    required String fileName,
    required Uint8List bytes,
    String? recordId,
    String? title,
  }) async {
    final form = FormData.fromMap({
      'module': module,
      'recordId': ?recordId,
      if (title != null && title.isNotEmpty) 'title': title,
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _apiClient.raw.post('/workspaces/$workspaceId/attachments', data: form);
    return Attachment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Uint8List> download(String workspaceId, String attachmentId) async {
    final response = await _apiClient.raw.get<List<int>>(
      '/workspaces/$workspaceId/attachments/$attachmentId/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<void> delete(String workspaceId, String attachmentId) async {
    await _apiClient.raw.delete('/workspaces/$workspaceId/attachments/$attachmentId');
  }
}

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) => DocumentsRepository(ref.watch(apiClientProvider)));

/// Attachments for one record (`module` + `recordId`), or all GENERAL ones when recordId is null.
typedef AttachmentScope = ({String module, String? recordId});

final recordAttachmentsProvider = FutureProvider.family<List<Attachment>, AttachmentScope>((ref, scope) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(documentsRepositoryProvider).list(workspaceId, module: scope.module, recordId: scope.recordId);
});

/// The workspace-wide document library, filtered by module and search text.
typedef LibraryFilter = ({String? module, String search});

final documentLibraryProvider = FutureProvider.family<List<Attachment>, LibraryFilter>((ref, filter) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(documentsRepositoryProvider).list(workspaceId, module: filter.module, search: filter.search);
});
