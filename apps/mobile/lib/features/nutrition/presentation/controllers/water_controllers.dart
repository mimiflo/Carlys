import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../data/datasources/water_local_data_source.dart';
import 'nutrition_controllers.dart';

/// Quantités proposées au pouce. Un verre, une grande bouteille.
const int waterGlassMl = 250;
const int waterBottleMl = 500;

/// Source des données d'hydratation.
///
/// Une INTERFACE, et non le data source directement : le mode démo la
/// remplace par une version en mémoire, comme tous les autres dépôts — sans
/// elle, la démonstration devrait ouvrir une base pour un compteur.
abstract interface class WaterStore {
  Stream<int> watchToday();
  Future<int> addToday(int milliliters);
}

class LocalWaterStore implements WaterStore {
  const LocalWaterStore(this._source);

  final WaterLocalDataSource _source;

  @override
  Stream<int> watchToday() => _source.watchDay(DateTime.now());

  @override
  Future<int> addToday(int milliliters) =>
      _source.add(DateTime.now(), milliliters);
}

final waterStoreProvider = Provider<WaterStore>((ref) {
  return LocalWaterStore(WaterLocalDataSource(ref.watch(appDatabaseProvider)));
});

/// Millilitres bus aujourd'hui. Flux : le total suit le geste sans que
/// l'écran ait à invalider quoi que ce soit.
final consumedWaterTodayProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(waterStoreProvider).watchToday();
});

/// Objectif d'eau du jour, en millilitres — calculé côté serveur avec le
/// reste du métabolisme. `null` tant qu'aucun profil n'est rempli.
final metabolismTargetWaterMlProvider = Provider.autoDispose<AsyncValue<int?>>((
  ref,
) {
  return ref
      .watch(metabolismReportProvider)
      .whenData((report) => report.metabolism?.waterMl);
});

/// Ajoute (ou retire, si négatif) de l'eau au total du jour.
final waterActionsProvider = Provider<WaterActions>((ref) {
  return WaterActions(ref);
});

class WaterActions {
  const WaterActions(this._ref);

  final Ref _ref;

  Future<void> add(int milliliters) =>
      _ref.read(waterStoreProvider).addToday(milliliters);
}
