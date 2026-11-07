import '../health_data_source.dart';

/// **Les pas du jour** : de minuit LOCAL à maintenant.
///
/// Minuit se construit en jour civil (`DateTime(année, mois, jour)`), jamais
/// en retranchant une durée : le jour du changement d'heure fait 23 ou 25 h.
///
/// Les pas ne quittent pas l'appareil : lus, affichés, oubliés — comme l'eau,
/// un compteur du jour n'a rien à raconter à un autre appareil.
class ReadTodaySteps {
  const ReadTodaySteps(this._source);

  final HealthDataSource _source;

  Future<int?> call(DateTime now) {
    final local = now.toLocal();
    return _source.stepsBetween(
      DateTime(local.year, local.month, local.day),
      local,
    );
  }
}
