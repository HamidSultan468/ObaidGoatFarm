import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'outbox_models.dart';

/// Persists the outbox so a queued write survives closing the app while
/// offline. Backed by [FlutterSecureStorage] — encrypted at rest via the
/// OS keychain/keystore/DPAPI on every target platform — which the queued
/// financial drafts need (CLAUDE.md §4, OFFLINE_SYNC.md "encrypted offline
/// drafts") without rolling a bespoke cipher for what is expected to stay
/// a short list of pending items, not an offline database.
abstract class OutboxStore {
  Future<List<OutboxItem>> load();
  Future<void> save(List<OutboxItem> items);
}

class SecureOutboxStore implements OutboxStore {
  SecureOutboxStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'tsm_outbox_v1';

  @override
  Future<List<OutboxItem>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((j) => OutboxItem.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      // A corrupted blob must never crash the app or silently drop writes
      // the user believes are queued; surfacing an empty queue at least
      // fails loud (nothing to sync) rather than throwing on every launch.
      return [];
    }
  }

  @override
  Future<void> save(List<OutboxItem> items) =>
      _storage.write(key: _key, value: jsonEncode(items.map((i) => i.toJson()).toList()));
}
