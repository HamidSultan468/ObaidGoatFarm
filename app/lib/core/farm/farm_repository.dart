import 'package:dio/dio.dart';
import '../api/api_client.dart';
import 'farm_models.dart';

/// See accounting_repository.dart's `_idempotent` — same header, same purpose.
Options _idempotent(String? key) => Options(headers: key == null ? null : {'Idempotency-Key': key});

/// Dates go to the API as plain `yyyy-MM-dd` (calendar dates, no time zone).
String apiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class FarmRepository {
  FarmRepository(this._apiClient);

  final ApiClient _apiClient;

  String _ws(String workspaceId) => '/workspaces/$workspaceId';

  Future<FarmOverview> getOverview(String workspaceId) async {
    final response = await _apiClient.raw.get('${_ws(workspaceId)}/farm/overview');
    return FarmOverview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Animal>> listAnimals(String workspaceId, {String status = 'ACTIVE', String? search}) async {
    final response = await _apiClient.raw.get(
      '${_ws(workspaceId)}/animals',
      queryParameters: {'status': status, if (search != null && search.isNotEmpty) 'search': search},
    );
    return (response.data as List).map((json) => Animal.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Animal> getAnimal(String workspaceId, String animalId) async {
    final response = await _apiClient.raw.get('${_ws(workspaceId)}/animals/$animalId');
    return Animal.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Animal> createAnimal(String workspaceId, Map<String, dynamic> body) async {
    final response = await _apiClient.raw.post('${_ws(workspaceId)}/animals', data: body);
    return Animal.fromJson(response.data as Map<String, dynamic>);
  }

  /// [ifMatch] is the `updatedAt` the caller last read; the server rejects
  /// with 412 if the record has changed since (DECISIONS.md D038) rather
  /// than silently overwriting a concurrent edit.
  Future<void> updateAnimal(String workspaceId, String animalId, Map<String, dynamic> body, {DateTime? ifMatch}) async {
    await _apiClient.raw.patch(
      '${_ws(workspaceId)}/animals/$animalId',
      data: body,
      options: Options(headers: ifMatch == null ? null : {'If-Match': ifMatch.toIso8601String()}),
    );
  }

  Future<void> recordExit(String workspaceId, String animalId, {required String status, required DateTime exitDate, String? reason}) async {
    await _apiClient.raw.post(
      '${_ws(workspaceId)}/animals/$animalId/exit',
      data: {'status': status, 'exitDate': apiDate(exitDate), if (reason != null && reason.isNotEmpty) 'exitReason': reason},
    );
  }

  Future<List<HealthRecord>> listHealthRecords(String workspaceId, String animalId) async {
    final response = await _apiClient.raw.get('${_ws(workspaceId)}/animals/$animalId/health-records');
    return (response.data as List).map((json) => HealthRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> addHealthRecord(String workspaceId, String animalId, Map<String, dynamic> body, {String? idempotencyKey}) async {
    await _apiClient.raw.post('${_ws(workspaceId)}/animals/$animalId/health-records', data: body, options: _idempotent(idempotencyKey));
  }

  Future<List<WeightRecord>> listWeights(String workspaceId, String animalId) async {
    final response = await _apiClient.raw.get('${_ws(workspaceId)}/animals/$animalId/weights');
    return (response.data as List).map((json) => WeightRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> addWeight(
    String workspaceId,
    String animalId, {
    required DateTime recordDate,
    required String weightKg,
    String? idempotencyKey,
  }) async {
    await _apiClient.raw.post(
      '${_ws(workspaceId)}/animals/$animalId/weights',
      data: {'recordDate': apiDate(recordDate), 'weightKg': weightKg},
      options: _idempotent(idempotencyKey),
    );
  }

  Future<Profitability> getAnimalLedger(String workspaceId, String animalId) async {
    final response = await _apiClient.raw.get('${_ws(workspaceId)}/animals/$animalId/ledger');
    return Profitability.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<BreedingRecord>> listBreeding(String workspaceId) async {
    final response = await _apiClient.raw.get('${_ws(workspaceId)}/breeding');
    return (response.data as List).map((json) => BreedingRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> createBreeding(String workspaceId, Map<String, dynamic> body) async {
    await _apiClient.raw.post('${_ws(workspaceId)}/breeding', data: body);
  }

  Future<void> updateBreedingStatus(String workspaceId, String recordId, String status) async {
    await _apiClient.raw.patch('${_ws(workspaceId)}/breeding/$recordId/status', data: {'status': status});
  }

  Future<void> recordKidding(
    String workspaceId,
    String recordId, {
    required DateTime kiddingDate,
    required int kidsBorn,
    required List<NewKid> kids,
    String? complications,
  }) async {
    await _apiClient.raw.post(
      '${_ws(workspaceId)}/breeding/$recordId/kidding',
      data: {
        'kiddingDate': apiDate(kiddingDate),
        'kidsBorn': kidsBorn,
        'kids': kids.map((kid) => kid.toJson()).toList(),
        if (complications != null && complications.isNotEmpty) 'complications': complications,
      },
    );
  }
}
