import 'package:app/core/api/token_storage.dart';
import 'package:app/core/offline/outbox_models.dart';
import 'package:app/core/offline/outbox_store.dart';

/// Shared across widget tests so ApiClient never touches the real
/// flutter_secure_storage platform channel, which isn't mocked in
/// `flutter test`'s environment.
class InMemoryTokenStorage implements TokenStorage {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Same idea as [InMemoryTokenStorage], for OutboxController — avoids the
/// real flutter_secure_storage platform channel in widget tests.
class InMemoryOutboxStore implements OutboxStore {
  List<OutboxItem> _items = const [];

  @override
  Future<List<OutboxItem>> load() async => _items;

  @override
  Future<void> save(List<OutboxItem> items) async => _items = items;
}
