import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/api/api_client.dart';
import 'package:app/core/auth/auth_controller.dart';
import 'package:app/core/l10n/locale_controller.dart';
import 'package:app/main.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('switching locale to Urdu renders Urdu text with RTL direction', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(ApiClient(tokenStorage: InMemoryTokenStorage()))],
    );
    addTearDown(container.dispose);

    container.read(localeProvider.notifier).setLocale(const Locale('ur'));

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TangentSmartManagerApp()),
    );
    await tester.pumpAndSettle();

    // Urdu for "Log in" (see lib/core/l10n/arb/app_ur.arb).
    expect(find.text('لاگ ان'), findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.ancestor(of: find.text('لاگ ان'), matching: find.byType(Directionality)).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });
}
