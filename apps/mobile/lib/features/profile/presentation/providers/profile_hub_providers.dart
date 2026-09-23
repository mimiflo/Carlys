import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/current_day.dart';
import '../../../community/presentation/controllers/community_controllers.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../progression/domain/reward.dart';
import '../../../progression/presentation/controllers/reward_controllers.dart';
import '../../../workout_program/domain/entities/program.dart';
import '../../../workout_program/domain/program_advancement.dart';
import '../../../workout_program/presentation/controllers/program_controllers.dart';

/// LES CHIFFRES DU PROFIL, chacun lu à sa source.
///
/// Aucun n'est recalculé ici : le profil PRÉSENTE ce que d'autres écrans
/// comptent déjà (règle du « fait déjà compté », `docs/product/
/// progression.md`). Chaque provider rend un `AsyncValue`, pour que l'écran
/// sépare « pas encore », « pas pu » et « zéro » — un zéro affiché hors
/// ligne serait un mensonge par omission.

/// Séances terminées depuis toujours, servies par le serveur.
///
/// Pas l'historique local : il est plafonné à 60 séances au rapatriement,
/// et un téléphone neuf afficherait 60 sur un compte qui en a 200.
final profileSessionsCountProvider = Provider.autoDispose<AsyncValue<int>>((
  ref,
) {
  return ref
      .watch(lifetimeStatsProvider)
      .whenData((stats) => stats.completedSessions);
});

/// Amis acceptés.
final profileFriendsCountProvider = Provider.autoDispose<AsyncValue<int>>((
  ref,
) {
  return ref
      .watch(communityFriendsProvider)
      .whenData((friends) => friends.length);
});

/// Badges gagnés — la famille « badge » seule, pas toutes les récompenses :
/// la ligne dit « 3 badges », et compter les médailles dedans la ferait
/// mentir sur ce qu'elle nomme.
final profileBadgeCountProvider = Provider.autoDispose<AsyncValue<int>>((ref) {
  return ref
      .watch(earnedRewardsProvider)
      .whenData(
        (earned) => earned
            .where((entry) => entry.reward.kind == RewardKind.badge)
            .length,
      );
});

/// Le programme SUIVI, en détail, ou `null` s'il n'y en a aucun.
///
/// Le serveur n'en active qu'un à la fois. Le détail est nécessaire pour le
/// rythme : le résumé de la liste ne porte pas ses jours.
final activeProgramProvider = FutureProvider.autoDispose<ProgramDetail?>((
  ref,
) async {
  final programs = await ref.watch(programsProvider.future);
  for (final program in programs) {
    if (program.isActive) {
      return ref.watch(programDetailProvider(program.id).future);
    }
  }
  return null;
});

/// La position d'aujourd'hui dans le programme suivi : `null` sans
/// programme, ou pour un programme qui n'a pas de premier jour.
///
/// Le jour vient de [currentDayProvider], pas de l'horloge : l'avancement
/// change à minuit même si le profil reste ouvert.
final activeProgramAdvancementProvider =
    Provider.autoDispose<AsyncValue<ProgramAdvancement?>>((ref) {
      final today = ref.watch(currentDayProvider);
      return ref
          .watch(activeProgramProvider)
          .whenData(
            (program) => program == null
                ? null
                : programAdvancement(
                    startsOn: program.startsOn,
                    weeksCount: program.weeksCount,
                    today: today,
                  ),
          );
    });
