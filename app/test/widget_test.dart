import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/token_storage.dart';
import 'package:app/core/auth/auth_controller.dart';
import 'package:app/main.dart';

class _InMemoryTokenStorage implements TokenStorage {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  testWidgets('app boots to the login screen when no session exists', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(tokenStorage: _InMemoryTokenStorage())),
        ],
        child: const TangentSmartManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tangent Smart Manager'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
