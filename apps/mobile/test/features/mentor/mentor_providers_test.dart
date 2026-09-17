import 'package:carlys_mobile/features/mentor/data/mentor_prefs_store.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_style.dart';
import 'package:carlys_mobile/features/mentor/presentation/controllers/mentor_controllers.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/reward_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le mot du Mentor à l'accueil : quand il parle, quand il se tait, et
/// comment une célébration ne se dit qu'une fois.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fraiche = EarnedReward(
    reward: const Reward(
      id: 'maitrise-5',
      label: 'Cinq leçons abordées',
      story: 'Cinq questions abordées dans l’Academy.',
      kind: RewardKind.medaille,
    ),
    earnedAt: DateTime.utc(2026, 9, 17),
    isNew: true,
  );

  ProviderContainer monter({
    List<EarnedReward> recompenses = const [],
    MentorStyle? style,
  }) {
    final container = ProviderContainer(
      overrides: [
        earnedRewardsProvider.overrideWith((ref) async => recompenses),
        currentMentorStyleProvider.overrideWithValue(style),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> chargerTout(ProviderContainer container) async {
    await container.read(mentorPrefsProvider.future);
    await container.read(mentorCelebrationsDitesProvider.future);
    await container.read(earnedRewardsProvider.future);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test('interventions coupées : le Mentor se TAIT, pas de carte', () async {
    SharedPreferences.setMockInitialValues(const {
      MentorPrefsStore.interventionsKey: false,
    });
    final container = monter();
    await chargerTout(container);

    expect(container.read(mentorWordProvider), isNull);
  });

  test(
    'une récompense fraîche prend la parole, puis se tait une fois dite',
    () async {
      final container = monter(
        recompenses: [fraiche],
        style: MentorStyle.exigeant,
      );
      await chargerTout(container);

      final mot = container.read(mentorWordProvider);
      expect(mot?.estCelebration, isTrue);
      expect(mot?.celebratedRewardId, 'maitrise-5');

      await container
          .read(mentorActionsProvider)
          .marquerCelebrationDite('maitrise-5');
      await container.read(mentorCelebrationsDitesProvider.future);

      final apres = container.read(mentorWordProvider);
      expect(apres, isNotNull, reason: 'Le mot ordinaire reprend la main.');
      expect(apres?.estCelebration, isFalse);
    },
  );

  test(
    'une récompense ANCIENNE (première lecture) ne se fête jamais',
    () async {
      // isNew est faux quand le journal vient d'être reconstruit : quinze
      // médailles inscrites d'un coup, aucune fête — la garde vit dans le
      // journal, le Mentor la respecte en ne lisant que isNew.
      final ancienne = EarnedReward(
        reward: fraiche.reward,
        earnedAt: fraiche.earnedAt,
      );
      final container = monter(recompenses: [ancienne]);
      await chargerTout(container);

      expect(container.read(mentorWordProvider)?.estCelebration, isFalse);
    },
  );
}
