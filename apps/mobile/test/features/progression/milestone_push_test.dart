import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progression/data/milestone_push.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/reward_engine.dart';
import 'package:carlys_mobile/features/progression/presentation/providers/reward_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_progress_repository.dart';

/// LE JOURNAL DES RÉCOMPENSES NE REMONTE QUE S'IL A CHANGÉ.
///
/// Il partait en entier à chaque recalcul des récompenses : 1 envoi au
/// démarrage, 3 pour une séance close puis synchronisée, 2 pour une réponse
/// à la question du jour, chacun réécrivant côté serveur toutes les lignes
/// déjà connues.
void main() {
  late FakeProgressRepository repository;

  setUp(() {
    repository = FakeProgressRepository();
  });

  group('MilestonePush', () {
    final debut = DateTime.utc(2026, 9, 1, 10);

    test('le même journal ne repart pas', () async {
      final push = MilestonePush(repository);
      await push.push({'constance-2': debut});
      // Relu du journal, le même instant revient en heure LOCALE : c'est le
      // même journal.
      await push.push({'constance-2': debut.toLocal()});

      expect(repository.pushAttempts, 1);
    });

    test('un journal qui grandit repart', () async {
      final push = MilestonePush(repository);
      await push.push({'constance-2': debut});
      await push.push({'constance-2': debut, 'discipline-10': debut});

      expect(repository.pushedMilestones, hasLength(2));
    });

    test('un envoi ÉCHOUÉ se retente au recalcul suivant', () async {
      // C'est la reprise que « ne pousser que le nouveau » aurait cassée :
      // cet envoi est le seul nouvel essai d'un jalon remonté hors ligne.
      final push = MilestonePush(repository);
      repository.pushFails = true;
      await push.push({'discipline-10': debut});
      repository.pushFails = false;
      await push.push({'discipline-10': debut});

      expect(repository.pushAttempts, 2);
      expect(repository.pushedMilestones.single.keys, ['discipline-10']);
    });
  });

  test('des faits égaux ne relancent pas le calcul des récompenses', () async {
    // Records relus, séance passée à « synchronisée » : les faits sortaient
    // IDENTIQUES mais neufs, et tout se rejouait : journal lu, réécrit,
    // remonté.
    SharedPreferences.setMockInitialValues({});
    final tick = StateProvider<int>((ref) => 0);
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repository),
        rewardFactsProvider.overrideWith((ref) {
          ref.watch(tick);
          // Une instance NEUVE à chaque fois, comme `buildRewardFacts` :
          // surtout pas `const`, qui rendrait toujours la même.
          // ignore: prefer_const_constructors
          return RewardFacts(
            reachedTitle: CarlysTitle.apprenti,
            completedSessions: 12,
            bestWeekStreak: 4,
            balancedWeeks: 4,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    var recalculs = 0;
    final sub = container.listen(earnedRewardsProvider, (_, _) => recalculs++);
    addTearDown(sub.close);
    await container.read(earnedRewardsProvider.future);
    await pumpEventQueue();
    final auDemarrage = recalculs;

    for (var fois = 1; fois <= 3; fois++) {
      container.read(tick.notifier).state = fois;
      await container.read(earnedRewardsProvider.future);
      await pumpEventQueue();
    }

    expect(recalculs, auDemarrage);
    expect(repository.pushAttempts, 1);
  });
}
