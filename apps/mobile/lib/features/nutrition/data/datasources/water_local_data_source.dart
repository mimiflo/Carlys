import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';

/// Accès Drift de l'hydratation du jour.
///
/// Une ligne par journée, écrite en `insertOnConflictUpdate` : le geste est
/// répété des dizaines de fois par jour, il ne doit jamais faire grossir la
/// base ni demander de savoir si la ligne existe déjà.
///
/// Le total est BORNÉ à zéro : retirer un verre qu'on n'a pas bu ramène à
/// zéro, jamais en négatif — un compteur d'eau négatif ne veut rien dire, et
/// c'est au plus près du stockage que la règle tient le mieux.
class WaterLocalDataSource {
  const WaterLocalDataSource(this._db);

  final AppDatabase _db;

  /// Minuit local du jour donné : la clé de la ligne.
  static DateTime dayOf(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  Stream<int> watchDay(DateTime day) {
    final query = _db.select(_db.localWaterIntakes)
      ..where((row) => row.day.equals(dayOf(day)));
    return query.watchSingleOrNull().map((row) => row?.milliliters ?? 0);
  }

  Future<int> read(DateTime day) async {
    final query = _db.select(_db.localWaterIntakes)
      ..where((row) => row.day.equals(dayOf(day)));
    final row = await query.getSingleOrNull();
    return row?.milliliters ?? 0;
  }

  /// Ajoute (ou retire, si négatif) une quantité et rend le nouveau total.
  Future<int> add(DateTime day, int milliliters) async {
    final key = dayOf(day);
    return _db.transaction(() async {
      final current = await read(key);
      final next = (current + milliliters).clamp(0, _dailyCeiling);
      await _db
          .into(_db.localWaterIntakes)
          .insertOnConflictUpdate(
            LocalWaterIntakesCompanion.insert(
              day: key,
              milliliters: Value(next),
              updatedAt: DateTime.now(),
            ),
          );
      return next;
    });
  }

  /// Plafond de garde : vingt litres. Personne ne boit ça, mais un doigt
  /// resté appuyé ne doit pas pouvoir écrire un nombre absurde.
  static const int _dailyCeiling = 20000;
}
