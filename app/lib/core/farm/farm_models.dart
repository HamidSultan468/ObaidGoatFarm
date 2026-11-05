/// Goat Farm data models. Weights and money stay as decimal strings from the
/// API (never parsed to double), matching the backend's Decimal columns.
library;

DateTime? _date(Object? value) => value is String ? DateTime.parse(value) : null;

class AnimalRef {
  const AnimalRef({required this.id, required this.tagNumber, this.name});

  final String id;
  final String tagNumber;
  final String? name;

  String get label => name == null || name!.isEmpty ? tagNumber : '$tagNumber · $name';

  factory AnimalRef.fromJson(Map<String, dynamic> json) =>
      AnimalRef(id: json['id'] as String, tagNumber: json['tagNumber'] as String, name: json['name'] as String?);
}

class Animal {
  const Animal({
    required this.id,
    required this.tagNumber,
    required this.sex,
    required this.species,
    required this.status,
    required this.healthStatus,
    required this.acquisition,
    this.name,
    this.breed,
    this.dateOfBirth,
    this.color,
    this.acquisitionDate,
    this.ownership,
    this.dietaryRestrictions,
    this.notes,
    this.exitDate,
    this.exitReason,
    this.sire,
    this.dam,
    this.latestWeightKg,
    this.offspring = const [],
    this.updatedAt,
    this.photoAttachmentId,
  });

  final String id;
  final String tagNumber;
  final String sex;
  final String species;
  final String status;
  final String healthStatus;
  final String acquisition;
  /// Set on records fetched from the API; used as an optimistic-concurrency
  /// check (`If-Match`) so one person's edit can't silently clobber
  /// another's (OFFLINE_SYNC.md, DECISIONS.md D038). Null on records not
  /// read from the server (there is none for a brand-new local draft).
  final DateTime? updatedAt;
  final String? name;
  final String? breed;
  final DateTime? dateOfBirth;
  final String? color;
  final DateTime? acquisitionDate;
  final String? ownership;
  final String? dietaryRestrictions;
  final String? notes;
  final DateTime? exitDate;
  final String? exitReason;
  final AnimalRef? sire;
  final AnimalRef? dam;
  final String? latestWeightKg;
  final List<AnimalRef> offspring;
  final String? photoAttachmentId;

  AnimalRef get ref => AnimalRef(id: id, tagNumber: tagNumber, name: name);
  bool get isActive => status == 'ACTIVE';

  factory Animal.fromJson(Map<String, dynamic> json) {
    final weights = json['weightRecords'] as List?;
    return Animal(
      id: json['id'] as String,
      tagNumber: json['tagNumber'] as String,
      sex: json['sex'] as String,
      species: json['species'] as String? ?? 'GOAT',
      status: json['status'] as String,
      healthStatus: json['healthStatus'] as String,
      acquisition: json['acquisition'] as String,
      name: json['name'] as String?,
      breed: json['breed'] as String?,
      dateOfBirth: _date(json['dateOfBirth']),
      color: json['color'] as String?,
      acquisitionDate: _date(json['acquisitionDate']),
      ownership: json['ownership'] as String?,
      dietaryRestrictions: json['dietaryRestrictions'] as String?,
      notes: json['notes'] as String?,
      exitDate: _date(json['exitDate']),
      exitReason: json['exitReason'] as String?,
      sire: json['sire'] is Map ? AnimalRef.fromJson(json['sire'] as Map<String, dynamic>) : null,
      dam: json['dam'] is Map ? AnimalRef.fromJson(json['dam'] as Map<String, dynamic>) : null,
      latestWeightKg: weights != null && weights.isNotEmpty ? (weights.first as Map<String, dynamic>)['weightKg'] as String : null,
      offspring: ((json['offspring'] as List?) ?? const [])
          .map((child) => AnimalRef.fromJson(child as Map<String, dynamic>))
          .toList(),
      updatedAt: _date(json['updatedAt']),
      photoAttachmentId: json['photoAttachmentId'] as String?,
    );
  }
}

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.type,
    required this.recordDate,
    required this.description,
    this.medication,
    this.dosage,
    this.veterinarian,
    this.nextDueDate,
  });

  final String id;
  final String type;
  final DateTime recordDate;
  final String description;
  final String? medication;
  final String? dosage;
  final String? veterinarian;
  final DateTime? nextDueDate;

  factory HealthRecord.fromJson(Map<String, dynamic> json) => HealthRecord(
    id: json['id'] as String,
    type: json['type'] as String,
    recordDate: DateTime.parse(json['recordDate'] as String),
    description: json['description'] as String,
    medication: json['medication'] as String?,
    dosage: json['dosage'] as String?,
    veterinarian: json['veterinarian'] as String?,
    nextDueDate: _date(json['nextDueDate']),
  );
}

class WeightRecord {
  const WeightRecord({required this.id, required this.recordDate, required this.weightKg, this.notes});

  final String id;
  final DateTime recordDate;
  final String weightKg;
  final String? notes;

  factory WeightRecord.fromJson(Map<String, dynamic> json) => WeightRecord(
    id: json['id'] as String,
    recordDate: DateTime.parse(json['recordDate'] as String),
    weightKg: json['weightKg'] as String,
    notes: json['notes'] as String?,
  );
}

class BreedingRecord {
  const BreedingRecord({
    required this.id,
    required this.dam,
    required this.method,
    required this.matingDate,
    required this.expectedKiddingDate,
    required this.status,
    this.sire,
    this.externalSire,
    this.kiddingDate,
    this.kidsBorn,
    this.kidsAlive,
  });

  final String id;
  final AnimalRef dam;
  final AnimalRef? sire;
  final String? externalSire;
  final String method;
  final DateTime matingDate;
  final DateTime expectedKiddingDate;
  final String status;
  final DateTime? kiddingDate;
  final int? kidsBorn;
  final int? kidsAlive;

  bool get isOpen => status == 'MATED' || status == 'PREGNANT';
  String get sireLabel => sire?.label ?? externalSire ?? 'Unknown';

  factory BreedingRecord.fromJson(Map<String, dynamic> json) => BreedingRecord(
    id: json['id'] as String,
    dam: AnimalRef.fromJson(json['dam'] as Map<String, dynamic>),
    sire: json['sire'] is Map ? AnimalRef.fromJson(json['sire'] as Map<String, dynamic>) : null,
    externalSire: json['externalSire'] as String?,
    method: json['method'] as String,
    matingDate: DateTime.parse(json['matingDate'] as String),
    expectedKiddingDate: DateTime.parse(json['expectedKiddingDate'] as String),
    status: json['status'] as String,
    kiddingDate: _date(json['kiddingDate']),
    kidsBorn: json['kidsBorn'] as int?,
    kidsAlive: json['kidsAlive'] as int?,
  );
}

class DueHealthItem {
  const DueHealthItem({required this.id, required this.type, required this.description, required this.nextDueDate, required this.overdue, required this.animal});

  final String id;
  final String type;
  final String description;
  final DateTime nextDueDate;
  final bool overdue;
  final AnimalRef animal;

  factory DueHealthItem.fromJson(Map<String, dynamic> json) => DueHealthItem(
    id: json['id'] as String,
    type: json['type'] as String,
    description: json['description'] as String,
    nextDueDate: DateTime.parse(json['nextDueDate'] as String),
    overdue: json['overdue'] as bool,
    animal: AnimalRef.fromJson(json['animal'] as Map<String, dynamic>),
  );
}

class UpcomingKidding {
  const UpcomingKidding({required this.id, required this.status, required this.expectedKiddingDate, required this.dam});

  final String id;
  final String status;
  final DateTime expectedKiddingDate;
  final AnimalRef dam;

  factory UpcomingKidding.fromJson(Map<String, dynamic> json) => UpcomingKidding(
    id: json['id'] as String,
    status: json['status'] as String,
    expectedKiddingDate: DateTime.parse(json['expectedKiddingDate'] as String),
    dam: AnimalRef.fromJson(json['dam'] as Map<String, dynamic>),
  );
}

class FarmOverview {
  const FarmOverview({
    required this.activeAnimals,
    required this.males,
    required this.females,
    required this.healthy,
    required this.needsAttention,
    required this.pregnant,
    required this.dueHealth,
    required this.upcomingKiddings,
  });

  final int activeAnimals;
  final int males;
  final int females;
  final int healthy;
  final int needsAttention;
  final int pregnant;
  final List<DueHealthItem> dueHealth;
  final List<UpcomingKidding> upcomingKiddings;

  factory FarmOverview.fromJson(Map<String, dynamic> json) => FarmOverview(
    activeAnimals: json['activeAnimals'] as int,
    males: json['males'] as int,
    females: json['females'] as int,
    healthy: json['healthy'] as int,
    needsAttention: json['needsAttention'] as int,
    pregnant: json['pregnant'] as int,
    dueHealth: (json['dueHealth'] as List).map((e) => DueHealthItem.fromJson(e as Map<String, dynamic>)).toList(),
    upcomingKiddings: (json['upcomingKiddings'] as List).map((e) => UpcomingKidding.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

/// Per-animal or per-parcel profitability from tagged ledger entries.
class Profitability {
  const Profitability({required this.income, required this.expense, required this.net});

  final String income;
  final String expense;
  final String net;

  factory Profitability.fromJson(Map<String, dynamic> json) =>
      Profitability(income: json['income'] as String, expense: json['expense'] as String, net: json['net'] as String);
}

/// A kid to register when recording a kidding.
class NewKid {
  const NewKid({required this.tagNumber, required this.sex, this.name});

  final String tagNumber;
  final String sex;
  final String? name;

  Map<String, dynamic> toJson() => {'tagNumber': tagNumber, 'sex': sex, 'name': ?name};
}
