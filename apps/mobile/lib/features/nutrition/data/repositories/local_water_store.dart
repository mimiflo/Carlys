import 'dart:async';

import '../../domain/repositories/water_store.dart';
import '../datasources/water_local_data_source.dart';

/// Compteur d'hydratation local (Drift), qui SUIT le passage de minuit.
///
/// LE BOGUE QU'IL CORRIGE. `watchToday()` évaluait `DateTime.now()` une seule
/// fois, à la construction du flux, et le jour devenait une clause `WHERE`
/// figée pour toute la vie de l'abonnement. `addToday()`, lui, réévaluait
/// l'heure à chaque appel : l'écriture suivait le jour réel, la lecture non.
///
/// L'accueil observe ce flux (`today_metrics.dart`) et reste monté — c'est la
/// branche 0 d'un `StatefulShellRoute.indexedStack`. Ouvrir l'application à
/// 23 h 50, la rouvrir à 0 h 05 et ajouter un verre écrivait donc 250 ml sur
/// la ligne du nouveau jour pendant que l'écran continuait d'afficher le
/// total de la veille, sans bouger d'un millilitre quel que soit le nombre
/// d'appuis. L'écran promet pourtant l'inverse : « Compté sur cet appareil,
/// remis à zéro chaque nuit. » La remise à zéro avait bien lieu en base ;
/// elle n'était jamais rendue à l'écran.
///
/// CE QU'IL FAIT. Un minuteur armé sur le prochain minuit LOCAL réabonne le
/// flux au jour suivant. La durée se calcule par différence de deux instants,
/// jamais en supposant 24 h : un dimanche de changement d'heure, la nuit dure
/// 23 h ou 25 h, et un décalage fixe raterait la bascule d'une heure. À
/// chaque réveil l'heure est relue, si bien qu'un minuteur qui se déclenche
/// tard — l'application était en arrière-plan, l'isolat suspendu — retombe
/// quand même sur le bon jour.
class LocalWaterStore implements WaterStore {
  LocalWaterStore(this._source, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final WaterLocalDataSource _source;

  /// Horloge injectable — le déterminisme des tests de bascule en dépend.
  final DateTime Function() _now;

  /// Minuit LOCAL du lendemain de [moment].
  ///
  /// `dayOf(moment).add(const Duration(days: 1))` serait faux : `Duration`
  /// est une durée ABSOLUE, donc « plus un jour » rend 1 h du matin le
  /// dimanche où l'on recule d'une heure, et 23 h la veille quand on avance —
  /// la bascule se ferait alors une heure trop tôt ou trop tard, deux nuits
  /// par an. Le constructeur `DateTime` raisonne en jour CIVIL : `day + 1`
  /// passe au mois puis à l'année suivante tout seul, et rend l'instant local
  /// correspondant quel que soit le changement d'heure au milieu.
  static DateTime prochainMinuit(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day + 1);

  @override
  Stream<int> watchToday() {
    late final StreamController<int> sortie;
    StreamSubscription<int>? abonnement;
    Timer? minuit;

    void suivreLeJourCourant() {
      final maintenant = _now();
      unawaited(abonnement?.cancel());
      abonnement = _source
          .watchDay(maintenant)
          .listen(
            (total) {
              if (!sortie.isClosed) sortie.add(total);
            },
            onError: (Object error, StackTrace stack) {
              if (!sortie.isClosed) sortie.addError(error, stack);
            },
          );
      minuit?.cancel();
      minuit = Timer(prochainMinuit(maintenant).difference(maintenant), () {
        suivreLeJourCourant();
      });
    }

    sortie = StreamController<int>(
      onListen: suivreLeJourCourant,
      // SYNCHRONE, et sans `await` sur la fermeture Drift. L'annulation d'un
      // flux Drift attend la boucle d'événements réelle ; l'attendre ici
      // faisait dépendre `subscription.cancel()` de cette boucle, ce qui
      // suffit à bloquer indéfiniment un test de widget, où le temps est
      // simulé. Couper le minuteur est ce qui compte et ne demande rien à
      // personne ; la fermeture Drift suit à son rythme, sans que rien ne
      // l'attende.
      onCancel: () {
        minuit?.cancel();
        unawaited(abonnement?.cancel());
      },
    );
    return sortie.stream;
  }

  @override
  Future<int> addToday(int milliliters) => _source.add(_now(), milliliters);
}
