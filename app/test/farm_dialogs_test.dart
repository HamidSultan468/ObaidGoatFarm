import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/api/api_client.dart';
import 'package:app/core/farm/farm_controller.dart';
import 'package:app/core/farm/farm_models.dart';
import 'package:app/core/farm/farm_repository.dart';
import 'package:app/core/offline/connectivity_controller.dart';
import 'package:app/core/offline/outbox_controller.dart';
import 'package:app/core/workspace/workspace_controller.dart';
import 'package:app/core/workspace/workspace_models.dart';
import 'package:app/features/goat_farm/presentation/widgets/animal_dialogs.dart';
import 'package:app/features/goat_farm/presentation/widgets/breeding_dialogs.dart';

import 'test_helpers.dart';

const _workspace = Workspace(id: 'ws-1', name: 'Test Farm', slug: 'test-farm');

class _FakeWorkspaceController extends WorkspaceController {
  @override
  WorkspaceState build() => const WorkspaceSelected(_workspace, [_workspace]);
}

class _FakeFarmRepository extends FarmRepository {
  _FakeFarmRepository() : super(ApiClient(tokenStorage: InMemoryTokenStorage()));

  final created = <Map<String, dynamic>>[];
  final weights = <String>[];
  final kiddings = <List<NewKid>>[];

  @override
  Future<Animal> createAnimal(String workspaceId, Map<String, dynamic> body) async {
    created.add(body);
    return Animal.fromJson({...body, 'id': 'a-new', 'status': 'ACTIVE', 'healthStatus': 'HEALTHY', 'acquisition': body['acquisition'] ?? 'PURCHASED'});
  }

  @override
  Future<void> addWeight(
    String workspaceId,
    String animalId, {
    required DateTime recordDate,
    required String weightKg,
    String? idempotencyKey,
  }) async {
    weights.add(weightKg);
  }

  @override
  Future<void> recordKidding(
    String workspaceId,
    String recordId, {
    required DateTime kiddingDate,
    required int kidsBorn,
    required List<NewKid> kids,
    String? complications,
  }) async {
    kiddings.add(kids);
  }

  @override
  Future<List<Animal>> listAnimals(String workspaceId, {String status = 'ACTIVE', String? search}) async => [];

  @override
  Future<FarmOverview> getOverview(String workspaceId) async => const FarmOverview(
    activeAnimals: 0, males: 0, females: 0, healthy: 0, needsAttention: 0, pregnant: 0, dueHealth: [], upcomingKiddings: [],
  );

  @override
  Future<List<BreedingRecord>> listBreeding(String workspaceId) async => [];
}

Future<void> _open(WidgetTester tester, _FakeFarmRepository repository, Widget dialog) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        farmRepositoryProvider.overrideWithValue(repository),
        workspaceControllerProvider.overrideWith(_FakeWorkspaceController.new),
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
        outboxStoreProvider.overrideWithValue(InMemoryOutboxStore()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(onPressed: () => showDialog<bool>(context: context, builder: (_) => dialog), child: const Text('open')),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

final _breeding = BreedingRecord(
  id: 'br-1',
  dam: const AnimalRef(id: 'doe-1', tagNumber: 'D-1', name: 'Rani'),
  method: 'NATURAL',
  matingDate: DateTime.utc(2026, 6, 1),
  expectedKiddingDate: DateTime.utc(2026, 10, 29),
  status: 'PREGNANT',
);

void main() {
  testWidgets('Add animal: an empty tag blocks submit with no API call', (tester) async {
    final repository = _FakeFarmRepository();
    await _open(tester, repository, const AddAnimalDialog());

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enter a tag number'), findsOneWidget);
    expect(repository.created, isEmpty);
  });

  testWidgets('Add animal: sends the tag and sex, omits empty optional fields, then closes', (tester) async {
    final repository = _FakeFarmRepository();
    await _open(tester, repository, const AddAnimalDialog());

    await tester.enterText(find.widgetWithText(TextField, 'Tag number *'), 'G-101');
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Rani');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(repository.created.single, {'tagNumber': 'G-101', 'sex': 'FEMALE', 'acquisition': 'PURCHASED', 'name': 'Rani'});
    expect(find.byType(AddAnimalDialog), findsNothing);
  });

  testWidgets('Record weight: rejects zero and non-numbers, sends the exact decimal string', (tester) async {
    final repository = _FakeFarmRepository();
    await _open(tester, repository, const AddWeightDialog(animalId: 'a-1'));

    final field = find.widgetWithText(TextField, 'Weight (kg) *');
    for (final bad in ['0', 'abc', '12.3456']) {
      await tester.enterText(field, bad);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a weight in kg'), findsOneWidget, reason: bad);
    }
    expect(repository.weights, isEmpty);

    await tester.enterText(field, '32.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.weights, ['32.50']);
  });

  testWidgets('Record kidding: duplicate kid tags are blocked before any API call', (tester) async {
    final repository = _FakeFarmRepository();
    await _open(tester, repository, RecordKiddingDialog(record: _breeding));

    await tester.tap(find.text('Add kid'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Kid 1 tag *'), 'K-1');
    await tester.enterText(find.widgetWithText(TextField, 'Kid 2 tag *'), 'K-1');

    // Two live kids need "born" >= 2 first.
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Kid tag numbers must be different.'), findsOneWidget);
    expect(repository.kiddings, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Kid 2 tag *'), 'K-2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.kiddings.single.map((k) => k.tagNumber), ['K-1', 'K-2']);
  });

  testWidgets('Record kidding: more live kids than born is blocked', (tester) async {
    final repository = _FakeFarmRepository();
    await _open(tester, repository, RecordKiddingDialog(record: _breeding));

    await tester.tap(find.text('Add kid'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Kid 1 tag *'), 'K-1');
    await tester.enterText(find.widgetWithText(TextField, 'Kid 2 tag *'), 'K-2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('More live kids listed than born.'), findsOneWidget);
    expect(repository.kiddings, isEmpty);
  });
}
