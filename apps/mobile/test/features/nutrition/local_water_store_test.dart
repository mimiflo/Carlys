/// Le compteur d'hydratation suit-il le passage de minuit ?
///
/// Le flux figeait le jour à l'abonnement : « aujourd'hui » restait la date
/// de la première lecture pour toute la vie de l'écran, alors que l'écriture,
/// elle, réévaluait l'heure. L'accueil observe ce flux et reste monté la nuit
/// entière (branche 0 d'un `StatefulShellRoute.indexedStack`) : ouvrir
/// l'application à 23 h 50, la rouvrir à 0 h 05 et boire un verre écrivait
/// bien la ligne du nouveau jour, mais l'écran continuait d'afficher le total
/// de la veille — sans bouger d'un millilitre, quel que soit le nombre
/// d'appuis. L'écran promet pourtant « remis à zéro chaque nuit ».
library;

import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/features/nutrition/data/datasources/water_local_data_source.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/local_water_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late WaterLocalDataSource source;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    source = WaterLocalDataSource(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('le MÊME abonnement bascule sur le nouveau jour à minuit', () async {
    // Horloge à 100 ms de minuit : le minuteur du store est donc armé sur
    // 100 ms réelles, ce qu'un test peut attendre. C'est bien le minuteur
    // qui est éprouvé — on ne se réabonne jamais, et se réabonner aurait
    // suffi à rendre ce test vert AVEC le bogue, puisque l'ancien code
    // relisait lui aussi l'heure à chaque abonnement.
    var maintenant = DateTime(2026, 9, 15, 23, 59, 59, 900);
    final store = LocalWaterStore(source, now: () => maintenant);

    await store.addToday(2000);

    final vus = <int>[];
    final abonnement = store.watchToday().listen(vus.add);
    await pumpEventQueue();
    expect(vus.last, 2000, reason: 'le total de la veille, avant minuit');

    maintenant = DateTime(2026, 9, 16, 0, 5);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await pumpEventQueue();
    expect(
      vus.last,
      0,
      reason: 'nouveau jour, compteur remis à zéro — sans se réabonner',
    );

    // Et le verre bu après minuit se voit, ce qui était impossible avant :
    // l'écriture allait sur le 16, la lecture regardait le 15.
    await store.addToday(250);
    await pumpEventQueue();
    expect(vus.last, 250);

    // La veille n'a pas été touchée : c'est un nouveau jour, pas un effacement.
    expect(await source.read(DateTime(2026, 9, 15)), 2000);
    await abonnement.cancel();
  });

  test('l’abonnement annulé n’arme plus rien pour minuit', () async {
    // Le contrôle passe par une source ESPIONNE, et pas par « aucun minuteur
    // en suspens » : cette assertion-là n'existe que dans la liaison de test
    // des widgets, et un flux Drift ne se laisse pas annuler sous son horloge
    // simulée. Ce qui est observable sans elle, c'est le RÉABONNEMENT que le
    // minuteur déclenche — donc on le compte.
    var maintenant = DateTime(2026, 9, 15, 23, 59, 59, 900);
    final espionne = _SourceEspionne();
    final store = LocalWaterStore(espionne, now: () => maintenant);

    final abonnement = store.watchToday().listen((_) {});
    await pumpEventQueue();
    expect(espionne.abonnements, 1);

    await abonnement.cancel();
    maintenant = DateTime(2026, 9, 16, 0, 5);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(
      espionne.abonnements,
      1,
      reason:
          'le minuteur de minuit doit mourir avec l’abonnement : sinon il '
          'réveille un flux que plus personne n’écoute, toutes les nuits, '
          'pour la durée de vie du processus',
    );
  });

  group('prochainMinuit', () {
    test('rend le minuit civil suivant, mois et année compris', () {
      expect(
        LocalWaterStore.prochainMinuit(DateTime(2026, 9, 15, 23, 50)),
        DateTime(2026, 9, 16),
      );
      expect(
        LocalWaterStore.prochainMinuit(DateTime(2026, 9, 30, 12, 0)),
        DateTime(2026, 10, 1),
      );
      expect(
        LocalWaterStore.prochainMinuit(DateTime(2026, 12, 31, 23, 59)),
        DateTime(2027, 1, 1),
      );
    });

    test('vise minuit LOCAL les nuits de changement d’heure', () {
      // Dernier dimanche d'octobre 2026 : en Europe/Paris on recule d'une
      // heure, la journée dure 25 h. Ajouter une DURÉE de 24 h à minuit
      // rendrait 23 h le même jour — la bascule se ferait une heure trop
      // tôt, et le compteur afficherait la veille pendant soixante minutes.
      final debut = DateTime(2026, 10, 25);
      final suivant = LocalWaterStore.prochainMinuit(debut);
      expect(suivant, DateTime(2026, 10, 26));
      expect(suivant.hour, 0, reason: 'minuit, pas 23 h ni 1 h');

      if (debut.timeZoneOffset == suivant.timeZoneOffset) {
        // Fuseau sans changement d'heure (UTC des runners par défaut) : les
        // deux calculs coïncident, il n'y a rien à départager. On le DIT
        // plutôt que de rendre un vert creux.
        markTestSkipped(
          'Fuseau sans changement d’heure (${debut.timeZoneName}) : la garde '
          'est muette ici, elle mord sous TZ=Europe/Paris.',
        );
        return;
      }

      expect(
        suivant.difference(debut),
        const Duration(hours: 25),
        reason: 'la nuit où l’on recule d’une heure dure 25 h',
      );
      expect(
        debut.add(const Duration(days: 1)),
        isNot(suivant),
        reason:
            'c’est précisément le calcul naïf que prochainMinuit remplace : '
            'une DURÉE de 24 h ne fait pas un jour civil',
      );
    });
  });
}

/// Source d'hydratation qui COMPTE ses abonnements, sans base.
///
/// `LocalWaterStore` ne s'abonne à nouveau que sur déclenchement de son
/// minuteur de minuit : le compteur ci-dessous rend donc ce minuteur
/// observable depuis l'extérieur, ce qu'aucune assertion de `dart test` ne
/// sait faire autrement.
class _SourceEspionne implements WaterLocalDataSource {
  int abonnements = 0;
  final Map<DateTime, int> totaux = {};

  @override
  Stream<int> watchDay(DateTime day) {
    abonnements++;
    final jour = WaterLocalDataSource.dayOf(day);
    return Stream<int>.value(totaux[jour] ?? 0);
  }

  @override
  Future<int> read(DateTime day) async =>
      totaux[WaterLocalDataSource.dayOf(day)] ?? 0;

  @override
  Future<int> add(DateTime day, int milliliters) async {
    final jour = WaterLocalDataSource.dayOf(day);
    final suivant = ((totaux[jour] ?? 0) + milliliters).clamp(0, 20000);
    totaux[jour] = suivant;
    return suivant;
  }
}
