import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../academy/presentation/controllers/academy_controllers.dart';
import '../../../academy/presentation/providers/academy_progress_providers.dart';
import '../../../progress/data/repositories/progress_repository_impl.dart';
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
/// Les records et les compteurs de vie entière viennent du serveur : hors
/// ligne ils comptent zéro ou retombent sur l'historique local, et c'est
/// sans conséquence — le journal continue d'afficher ce qui est déjà
/// obtenu, et la dérivation ne retire jamais rien.
final rewardFactsProvider = Provider<RewardFacts?>((ref) {
  final history = ref.watch(workoutHistoryProvider);
  final answered = ref.watch(answeredLessonsProvider);
  final pack = ref.watch(academyPackProvider);
  final records = ref.watch(personalRecordsProvider);
  final lifetime = ref.watch(lifetimeStatsProvider);
  final profile = ref.watch(progressionProfileProvider);

  // TOUTES les sources doivent avoir répondu — données ou échec — avant de
  // rendre des faits. Un « a répondu » suffit : une source en erreur (les
  // records, hors ligne) ne doit pas bloquer les récompenses, mais une
  // source encore EN ROUTE, si. Sans cette garde, les faits partiels du
  // démarrage ouvraient le journal (`start()`) avec une histoire
  // incomplète : tout ce qui arrivait ensuite comptait comme fraîchement
  // gagné, et un appareil neuf rejouait les célébrations de tout un passé.
  final pret = [
    history,
    answered,
    pack,
    records,
    lifetime,
  ].every((source) => source.hasValue || source.hasError);
  if (!pret || history.valueOrNull == null || profile == null) {
    return null;
  }

  // Le couple leçons vient d'`AcademyProgress` : il compte les réponses
  // FILTRÉES par le pack courant, quand le magasin local en porte aussi
  // d'autres (leçon retirée d'une version à l'autre, réponses rapatriées
  // d'un appareil au pack plus grand). Comparé au total du pack, le compte
  // brut pouvait déclarer l'Academy terminée sans qu'elle le soit.
  final progress = ref.watch(academyProgressProvider);

  return buildRewardFacts(
    history: history.valueOrNull!,
    reachedTitle: profile.title,
    // Nul hors ligne : l'historique local reprend alors la main. Voir
    // `buildRewardFacts` — sous-compter n'efface rien, le journal ne
    // s'écrit qu'en ajout.
    lifetime: lifetime.valueOrNull,
    lessonsAnswered: progress?.abordees ?? 0,
    lessonsTotal: progress?.total ?? 0,
    academyDomainsCompleted: ref.watch(completedAcademyDomainsProvider),
    academyDomainsServed: progress?.domainesServis ?? 0,
    personalRecords: records.valueOrNull?.length ?? 0,
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

  // Le journal REMONTE, pour que la frise ait de quoi raconter. Tâche de
  // fond : l'échouer ne doit rien coûter à l'écran, et la plus ANCIENNE
  // date gagnant côté serveur, un rejeu ne réécrit jamais l'histoire.
  unawaited(_pousserLeJournal(ref, earned));

  // Les plus récentes d'abord : la vitrine s'ouvre sur ce qui vient d'être
  // gagné, pas sur le premier badge d'il y a six mois.
  earned.sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
  return earned;
});

/// Remonte le journal de CET appareil, sans jamais faire échouer l'écran.
///
/// Hors ligne, l'envoi échoue et le journal reste ce qu'il est : il n'a
/// jamais cessé d'être la mémoire locale. La prochaine lecture réessaiera,
/// et l'unicité côté serveur absorbe le rejeu.
Future<void> _pousserLeJournal(Ref ref, List<EarnedReward> earned) async {
  if (earned.isEmpty) {
    return;
  }
  try {
    await ref.read(progressRepositoryProvider).pushMilestones({
      for (final entry in earned) entry.reward.id: entry.earnedAt,
    });
  } on Object catch (error) {
    _logger.warning('Journal de récompenses non remonté', error: error);
  }
}

const _logger = AppLogger('RewardControllers');

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
    // `titleOfReward` relit la clé là où le catalogue l'écrit : le préfixe
    // reconstruit à la main ici aurait divergé en silence le jour où il
    // change, et la majesté de la mise en scène serait retombée sans que
    // rien ne le signale.
    final title = titleOfReward(entry.reward.id);
    if (title != null && title.index > highest.index) {
      highest = title;
    }
  }
  return highest;
});
