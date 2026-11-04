import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accounting/accounting_controller.dart';
import '../auth/auth_controller.dart';
import 'farm_models.dart';
import 'farm_repository.dart';

final farmRepositoryProvider = Provider<FarmRepository>((ref) => FarmRepository(ref.watch(apiClientProvider)));

/// Herd list filter: lifecycle status + free-text search (tag, name, breed).
class HerdFilter {
  const HerdFilter({this.status = 'ACTIVE', this.search = ''});

  final String status;
  final String search;

  HerdFilter copyWith({String? status, String? search}) =>
      HerdFilter(status: status ?? this.status, search: search ?? this.search);
}

final herdFilterProvider = NotifierProvider<HerdFilterController, HerdFilter>(HerdFilterController.new);

class HerdFilterController extends Notifier<HerdFilter> {
  @override
  HerdFilter build() => const HerdFilter();

  void setStatus(String status) => state = state.copyWith(status: status);
  void setSearch(String search) => state = state.copyWith(search: search.trim());
}

final herdProvider = FutureProvider<List<Animal>>((ref) {
  final workspaceId = requireWorkspaceId(ref);
  final filter = ref.watch(herdFilterProvider);
  return ref.read(farmRepositoryProvider).listAnimals(workspaceId, status: filter.status, search: filter.search);
});

/// Every animal regardless of status; used for parent/dam/sire pickers.
final allAnimalsProvider = FutureProvider<List<Animal>>((ref) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(farmRepositoryProvider).listAnimals(workspaceId, status: 'ALL');
});

final farmOverviewProvider = FutureProvider<FarmOverview>((ref) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(farmRepositoryProvider).getOverview(workspaceId);
});

final animalDetailProvider = FutureProvider.family<Animal, String>((ref, animalId) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(farmRepositoryProvider).getAnimal(workspaceId, animalId);
});

final healthRecordsProvider = FutureProvider.family<List<HealthRecord>, String>((ref, animalId) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(farmRepositoryProvider).listHealthRecords(workspaceId, animalId);
});

final weightsProvider = FutureProvider.family<List<WeightRecord>, String>((ref, animalId) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(farmRepositoryProvider).listWeights(workspaceId, animalId);
});

final animalLedgerProvider = FutureProvider.family<Profitability, String>((ref, animalId) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(farmRepositoryProvider).getAnimalLedger(workspaceId, animalId);
});

final breedingProvider = FutureProvider<List<BreedingRecord>>((ref) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.read(farmRepositoryProvider).listBreeding(workspaceId);
});

/// After any farm write: refresh lists, the overview, and (when given) one animal's detail views.
void invalidateFarm(WidgetRef ref, {String? animalId}) {
  ref.invalidate(herdProvider);
  ref.invalidate(allAnimalsProvider);
  ref.invalidate(farmOverviewProvider);
  ref.invalidate(breedingProvider);
  if (animalId != null) {
    ref.invalidate(animalDetailProvider(animalId));
    ref.invalidate(healthRecordsProvider(animalId));
    ref.invalidate(weightsProvider(animalId));
    ref.invalidate(animalLedgerProvider(animalId));
  }
}

/// Same as [invalidateFarm], for call sites that only hold a [Ref] (e.g. the
/// offline outbox controller, which runs outside widget build methods).
/// `WidgetRef` is not a subtype of `Ref` in Riverpod 3, hence the duplicate.
void invalidateFarmFromRef(Ref ref, {String? animalId}) {
  ref.invalidate(herdProvider);
  ref.invalidate(allAnimalsProvider);
  ref.invalidate(farmOverviewProvider);
  ref.invalidate(breedingProvider);
  if (animalId != null) {
    ref.invalidate(animalDetailProvider(animalId));
    ref.invalidate(healthRecordsProvider(animalId));
    ref.invalidate(weightsProvider(animalId));
    ref.invalidate(animalLedgerProvider(animalId));
  }
}
