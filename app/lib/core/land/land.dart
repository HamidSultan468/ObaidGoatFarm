import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accounting/accounting_controller.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../farm/farm_models.dart';

/// Display order for the area units the backend supports.
const areaUnits = ['KANAL', 'MARLA', 'ACRE', 'SQUARE_FOOT', 'SQUARE_METER', 'HECTARE'];

DateTime? _date(Object? value) => value is String ? DateTime.parse(value) : null;

class AreaBreakdown {
  const AreaBreakdown({required this.acre, required this.kanal, required this.marla, required this.squareFeet});

  final int acre;
  final int kanal;
  final int marla;
  final String squareFeet;

  /// `2 acre 4 kanal 5 marla` (zero parts dropped; leftover sq ft shown only when nothing else is).
  String get label {
    final parts = [if (acre > 0) '$acre acre', if (kanal > 0) '$kanal kanal', if (marla > 0) '$marla marla'];
    if (parts.isEmpty) return '$squareFeet sq ft';
    return parts.join(' ');
  }

  factory AreaBreakdown.fromJson(Map<String, dynamic> json) => AreaBreakdown(
    acre: json['acre'] as int,
    kanal: json['kanal'] as int,
    marla: json['marla'] as int,
    squareFeet: json['squareFeet'] as String,
  );
}

class LandParcel {
  const LandParcel({
    required this.id,
    required this.name,
    required this.tenure,
    required this.status,
    required this.areaValue,
    required this.areaUnit,
    required this.areaConversions,
    required this.areaBreakdown,
    this.location,
    this.surveyNumber,
    this.ownerName,
    this.landUse,
    this.acquisitionDate,
    this.counterpartyName,
    this.leaseStartDate,
    this.leaseEndDate,
    this.leaseTerms,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String tenure;
  final String status;
  final String areaValue;
  final String areaUnit;
  final Map<String, String> areaConversions;
  final AreaBreakdown areaBreakdown;
  final String? location;
  final String? surveyNumber;
  final String? ownerName;
  final String? landUse;
  final DateTime? acquisitionDate;
  final String? counterpartyName;
  final DateTime? leaseStartDate;
  final DateTime? leaseEndDate;
  final String? leaseTerms;
  final String? notes;
  /// Optimistic-concurrency check for `If-Match` on edits — see Animal.updatedAt.
  final DateTime? updatedAt;

  bool get isLeased => tenure != 'OWNED';

  factory LandParcel.fromJson(Map<String, dynamic> json) => LandParcel(
    id: json['id'] as String,
    name: json['name'] as String,
    tenure: json['tenure'] as String,
    status: json['status'] as String,
    areaValue: json['areaValue'] as String,
    areaUnit: json['areaUnit'] as String,
    areaConversions: (json['areaConversions'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
    areaBreakdown: AreaBreakdown.fromJson(json['areaBreakdown'] as Map<String, dynamic>),
    location: json['location'] as String?,
    surveyNumber: json['surveyNumber'] as String?,
    ownerName: json['ownerName'] as String?,
    landUse: json['landUse'] as String?,
    acquisitionDate: _date(json['acquisitionDate']),
    counterpartyName: (json['counterparty'] as Map<String, dynamic>?)?['name'] as String?,
    leaseStartDate: _date(json['leaseStartDate']),
    leaseEndDate: _date(json['leaseEndDate']),
    leaseTerms: json['leaseTerms'] as String?,
    notes: json['notes'] as String?,
    updatedAt: _date(json['updatedAt']),
  );
}

class LandProfitReport {
  const LandProfitReport({required this.rows, required this.total});
  final Map<String, Profitability> rows;
  final Profitability total;

  factory LandProfitReport.fromJson(Map<String, dynamic> json) => LandProfitReport(
    rows: {
      for (final row in (json['rows'] as List).cast<Map<String, dynamic>>())
        (row['parcel'] as Map<String, dynamic>)['id'] as String: Profitability.fromJson(row),
    },
    total: Profitability.fromJson(json['total'] as Map<String, dynamic>),
  );
}

class LandRepository {
  LandRepository(this._apiClient);
  final ApiClient _apiClient;

  String _base(String workspaceId) => '/workspaces/$workspaceId/land';

  Future<List<LandParcel>> list(String workspaceId, {String status = 'ACTIVE'}) async {
    final response = await _apiClient.raw.get(_base(workspaceId), queryParameters: {'status': status});
    return (response.data as List).map((json) => LandParcel.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<LandParcel> get(String workspaceId, String parcelId) async {
    final response = await _apiClient.raw.get('${_base(workspaceId)}/$parcelId');
    return LandParcel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LandParcel> create(String workspaceId, Map<String, dynamic> body) async {
    final response = await _apiClient.raw.post(_base(workspaceId), data: body);
    return LandParcel.fromJson(response.data as Map<String, dynamic>);
  }

  /// [ifMatch] is the `updatedAt` the caller last read — see
  /// FarmRepository.updateAnimal for why.
  Future<void> update(String workspaceId, String parcelId, Map<String, dynamic> body, {DateTime? ifMatch}) async {
    await _apiClient.raw.patch(
      '${_base(workspaceId)}/$parcelId',
      data: body,
      options: Options(headers: ifMatch == null ? null : {'If-Match': ifMatch.toIso8601String()}),
    );
  }

  Future<Profitability> ledger(String workspaceId, String parcelId) async {
    final response = await _apiClient.raw.get('${_base(workspaceId)}/$parcelId/ledger');
    return Profitability.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LandProfitReport> profitability(String workspaceId) async {
    final response = await _apiClient.raw.get('${_base(workspaceId)}/reports/profitability');
    return LandProfitReport.fromJson(response.data as Map<String, dynamic>);
  }
}

final landRepositoryProvider = Provider<LandRepository>((ref) => LandRepository(ref.watch(apiClientProvider)));

final landStatusFilterProvider = NotifierProvider<LandStatusFilter, String>(LandStatusFilter.new);

class LandStatusFilter extends Notifier<String> {
  @override
  String build() => 'ACTIVE';
  void set(String status) => state = status;
}

final landParcelsProvider = FutureProvider<List<LandParcel>>((ref) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(landRepositoryProvider).list(workspaceId, status: ref.watch(landStatusFilterProvider));
});

/// Every parcel regardless of status; for the transaction tag picker.
final allLandParcelsProvider = FutureProvider<List<LandParcel>>((ref) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(landRepositoryProvider).list(workspaceId, status: 'ALL');
});

final landParcelProvider = FutureProvider.family<LandParcel, String>((ref, parcelId) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(landRepositoryProvider).get(workspaceId, parcelId);
});

final landLedgerProvider = FutureProvider.family<Profitability, String>((ref, parcelId) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(landRepositoryProvider).ledger(workspaceId, parcelId);
});

final landProfitReportProvider = FutureProvider<LandProfitReport>((ref) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(landRepositoryProvider).profitability(workspaceId);
});

void invalidateLand(WidgetRef ref, {String? parcelId}) {
  ref.invalidate(landParcelsProvider);
  ref.invalidate(allLandParcelsProvider);
  ref.invalidate(landProfitReportProvider);
  if (parcelId != null) {
    ref.invalidate(landParcelProvider(parcelId));
    ref.invalidate(landLedgerProvider(parcelId));
  }
}
