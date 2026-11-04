import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../api/api_client.dart';
import 'analytics_models.dart';

class AnalyticsRepository {
  AnalyticsRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String workspaceId) => '/workspaces/$workspaceId/analytics';

  /// Report ids this member's role may open — drives the report picker so
  /// the menu never offers something the server would refuse (403).
  Future<List<String>> availableReports(String workspaceId) async {
    final response = await _apiClient.raw.get(_base(workspaceId));
    return (response.data as List).cast<String>();
  }

  Future<ReportResult> fetch(String workspaceId, String report, {String? from, String? to, String? asOf, String? action}) async {
    final response = await _apiClient.raw.get(
      '${_base(workspaceId)}/$report',
      queryParameters: {'from': ?from, 'to': ?to, 'asOf': ?asOf, 'action': ?action},
    );
    return ReportResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Raw bytes of the exported file; the caller hands these to
  /// `FilePicker.saveFile` (same pattern as the backup download).
  Future<Uint8List> export(
    String workspaceId,
    String report,
    String format, {
    String? from,
    String? to,
    String? asOf,
    String? action,
  }) async {
    final response = await _apiClient.raw.get<List<int>>(
      '${_base(workspaceId)}/$report/export',
      queryParameters: {'format': format, 'from': ?from, 'to': ?to, 'asOf': ?asOf, 'action': ?action},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }
}
