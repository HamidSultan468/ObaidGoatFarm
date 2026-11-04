/// What kind of write a queued item replays. Deliberately only ever
/// *creates* a record (income, expense, transfer, a weight, a health
/// record) — never an edit of an existing one. Posted ledger entries are
/// immutable anyway, so there is nothing for the outbox to "overwrite";
/// see OFFLINE_SYNC.md and DECISIONS.md D038.
enum OutboxKind { income, expense, transfer, animalWeight, animalHealth }

enum OutboxStatus {
  /// Not yet sent, or a prior attempt hit a connectivity problem and will
  /// be retried automatically when the app is next online.
  pending,

  /// Currently being sent.
  sending,

  /// The server rejected the request (e.g. a validation error). Will not
  /// be retried automatically — the data itself needs fixing or discarding.
  failed,
}

/// One queued write. `id` doubles as the Idempotency-Key sent with every
/// attempt, so a resend after a dropped connection is replayed by the
/// backend rather than posted twice (DECISIONS.md D037).
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.workspaceId,
    required this.kind,
    required this.summary,
    required this.payload,
    required this.createdAt,
    this.status = OutboxStatus.pending,
    this.lastError,
    this.attempts = 0,
    this.animalId,
  });

  final String id;
  final String workspaceId;
  final OutboxKind kind;

  /// One line for display, e.g. "Expense: 1,200.00 — feed".
  final String summary;

  /// Exactly the arguments the matching repository method needs (see
  /// OutboxController._send) — not a generic HTTP body, so a schema change
  /// in one call site can't silently desync from what's replayed here.
  final Map<String, dynamic> payload;

  final DateTime createdAt;
  final OutboxStatus status;
  final String? lastError;
  final int attempts;

  /// Set for animal-scoped items, so a successful send can invalidate that
  /// animal's detail screens in addition to the farm-wide lists.
  final String? animalId;

  OutboxItem copyWith({OutboxStatus? status, String? lastError, int? attempts}) => OutboxItem(
    id: id,
    workspaceId: workspaceId,
    kind: kind,
    summary: summary,
    payload: payload,
    createdAt: createdAt,
    status: status ?? this.status,
    lastError: lastError,
    attempts: attempts ?? this.attempts,
    animalId: animalId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'kind': kind.name,
    'summary': summary,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'lastError': lastError,
    'attempts': attempts,
    'animalId': animalId,
  };

  factory OutboxItem.fromJson(Map<String, dynamic> json) => OutboxItem(
    id: json['id'] as String,
    workspaceId: json['workspaceId'] as String,
    kind: OutboxKind.values.byName(json['kind'] as String),
    summary: json['summary'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: OutboxStatus.values.byName(json['status'] as String),
    lastError: json['lastError'] as String?,
    attempts: json['attempts'] as int? ?? 0,
    animalId: json['animalId'] as String?,
  );
}
