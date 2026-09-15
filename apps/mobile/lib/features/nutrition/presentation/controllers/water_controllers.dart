import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../data/datasources/water_local_data_source.dart';
import '../../data/repositories/local_water_store.dart';
import '../../domain/repositories/water_store.dart';
import 'nutrition_controllers.dart';

/// Quantités proposées au pouce. Un verre, une grande bouteille.
const int waterGlassMl = 250;
const int waterBottleMl = 500;

/// Câblage du compteur d'hydratation.
///
/// Le contrat vit dans `domain/repositories/`, son implémentation Drift dans
/// `data/repositories/` : ils étaient tous deux déclarés ICI, seul
/// `abstract interface class` du dépôt hors de `domain/`. Ce n'était pas
/// qu'une question de rangement — une implémentation posée à côté de son
/// provider se relit comme du câblage, et personne n'a vu qu'elle figeait le
/// jour à la création du flux.
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
