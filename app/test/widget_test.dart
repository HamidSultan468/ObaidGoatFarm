import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/api/api_client.dart';
import 'package:app/core/auth/auth_controller.dart';
import 'package:app/main.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('app boots to the login screen when no session exists', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(tokenStorage: InMemoryTokenStorage())),
        ],
        child: const TangentSmartManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tangent Smart Manager'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
