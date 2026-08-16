import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../academy/presentation/controllers/academy_controllers.dart';
import '../../../progress/domain/entities/progress.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../data/reward_ledger.dart';
import '../../domain/progression.dart';
import '../../domain/reward.dart';
import '../../domain/reward_engine.dart';
import '../../domain/reward_facts_builder.dart';
import 'progression_controllers.dart';

/// Les faits qui décident des récompenses.
///
/// Les records viennent du serveur : hors ligne ils comptent zéro, et c'est
/// sans conséquence — le journal continue d'afficher ceux déjà obtenus, et
/// la dérivation ne retire jamais rien.
final rewardFactsProvider = Provider<RewardFacts?>((ref) {
  final history = ref.watch(workoutHistoryProvider).valueOrNull;
  final profile = ref.watch(progressionProfileProvider);
  if (history == null || profile == null) {
    return null;
  }

  return buildRewardFacts(
    history: history,
    reachedTitle: profile.title,
    lessonsAnswered:
        ref.watch(answeredLessonsProvider).valueOrNull?.length ?? 0,
    lessonsTotal: ref.watch(academyPackProvider).valueOrNull?.length ?? 0,
    personalRecords:
        ref.watch(personalRecordsProvider).valueOrNull?.length ?? 0,
  );
});

/// Les récompenses obtenues, journal compris.
///
/// C'est ici que les deux mémoires se rejoignent : la dérivation dit ce qui
/// est mérité aujourd'hui, le journal dit depuis quand. Ce qui est mérité et
/// pas encore inscrit s'inscrit au passage — et RIEN ne se retire, même si
/// un fait est sorti de la fenêtre.
///
/// Non auto-disposé : l'accueil, le profil de progression et l'écran Progrès
/// lisent la même carte, et la relire à chaque navigation ferait clignoter
/// les récompenses.
final earnedRewardsProvider = FutureProvider<List<EarnedReward>>((ref) async {
  final facts = ref.watch(rewardFactsProvider);
  if (facts == null) {
    return const [];
  }

  final ledger = ref.read(rewardLedgerProvider);
  final journal = await ledger.read();
  final deserved = earnedRewards(facts);

  // La toute première lecture RECONSTRUIT l'histoire déjà vécue : sur un
  // compte qui s'entraîne depuis des mois, elle inscrit quinze médailles
  // d'un coup. Les graver ensemble ne célébrerait rien — les célébrations
  // commencent à la récompense suivante.
  final started = await ledger.hasStarted();

  // Les nouvelles s'inscrivent maintenant, à la date du jour. La date
  // retenue est celle de l'INSCRIPTION, pas celle du fait : l'application ne
  // sait pas quand exactement un cap a été franchi, et inventer une date
  // serait pire qu'en assumer une approximative.
  final now = DateTime.now();
  final fresh = await ledger.record(deserved.map((r) => r.id), now);
  await ledger.start();

  final earned = <EarnedReward>[];
  for (final reward in deserved) {
    earned.add(
      EarnedReward(
        reward: reward,
        earnedAt: journal[reward.id] ?? now,
        isNew: started && fresh.contains(reward.id),
      ),
    );
  }

  // Les plus récentes d'abord : la vitrine s'ouvre sur ce qui vient d'être
  // gagné, pas sur le premier badge d'il y a six mois.
  earned.sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
  return earned;
});

/// LA VITRINE : le journal, ET les records réellement soulevés.
///
/// Le journal raconte les caps ; les records racontent les gestes. Un profil
/// qui n'afficherait que les caps dirait « cinq records battus » sans jamais
/// dire lesquels — or c'est le mouvement et la charge qu'on est fier de
/// montrer, pas le compteur.
///
/// Les records viennent du serveur et ne sont pas inscrits au journal : ils
/// portent déjà leur propre date, et ils ne peuvent pas se perdre puisque
/// c'est le serveur qui les tient. Hors ligne, la vitrine se replie sur le
/// journal seul, et rien ne disparaît de ce qui était déjà gagné.
final showcaseRewardsProvider = Provider<List<EarnedReward>>((ref) {
  final journal = ref.watch(earnedRewardsProvider).valueOrNull ?? const [];
  final records = ref.watch(personalRecordsProvider).valueOrNull ?? const [];

  final showcase = [
    ...journal,
    for (final record in records)
      EarnedReward(
        reward: Reward(
          // Préfixé : l'identifiant d'un record vient du serveur, celui d'une
          // récompense du catalogue. Les mélanger sans préfixe exposerait à
          // une collision qui ferait disparaître l'un des deux.
          id: 'record-${record.id}',
          kind: RewardKind.record,
          label: '${record.exerciseName} · ${record.formattedValue}',
          story: _recordStory(record.type),
          value: CarlysValue.performance,
          figure: record.value.round().toString(),
        ),
        earnedAt: record.achievedAt,
      ),
  ]..sort((a, b) => b.earnedAt.compareTo(a.earnedAt));

  return showcase;
});

String _recordStory(PersonalRecordType type) => switch (type) {
      PersonalRecordType.maxWeight =>
        'Une charge que tu n’avais jamais tenue jusqu’ici.',
      PersonalRecordType.maxReps =>
        'Un nombre de répétitions jamais atteint sur ce mouvement.',
      PersonalRecordType.maxSetVolume =>
        'Le volume d’une série, jamais soulevé jusqu’ici.',
    };

/// Ce qui est à portée, pour dire quoi faire plutôt que d'afficher un vide.
final nextRewardsProvider = Provider<List<Reward>>((ref) {
  final facts = ref.watch(rewardFactsProvider);
  return facts == null ? const [] : nextRewards(facts);
});

/// Le titre le plus haut JAMAIS atteint, d'après le journal.
///
/// Le titre affiché suit les points et peut redescendre après une
/// interruption ; celui-ci ne se reprend pas. C'est lui qui décide de la
/// majesté de la mise en scène : personne ne doit voir son écran se ternir
/// parce qu'il a été malade deux semaines.
final highestTitleProvider = Provider<CarlysTitle>((ref) {
  final earned = ref.watch(earnedRewardsProvider).valueOrNull ?? const [];
  var highest =
      ref.watch(progressionProfileProvider)?.title ?? CarlysTitle.apprenti;
  for (final entry in earned) {
    if (entry.reward.kind != RewardKind.titre) continue;
    for (final title in CarlysTitle.values) {
      if (entry.reward.id == 'titre-${title.name}' &&
          title.index > highest.index) {
        highest = title;
      }
    }
  }
  return highest;
});
