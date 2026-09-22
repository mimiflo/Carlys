import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../domain/entities/program_calendar.dart';

/// Ce qu'on peut faire d'une case DATÉE du calendrier.
sealed class CalendarDayAction {
  const CalendarDayAction();
}

/// Lancer la séance prévue.
class LaunchDay extends CalendarDayAction {
  const LaunchDay();
}

/// Faire reconnaître par la case une séance déjà faite ce jour-là.
class LinkSessionToDay extends CalendarDayAction {
  const LinkSessionToDay(this.sessionId);

  final String sessionId;
}

/// Détacher la séance que la case reconnaît.
class UnlinkSessionFromDay extends CalendarDayAction {
  const UnlinkSessionFromDay();
}

/// La feuille d'une case du calendrier : son état en toutes lettres, et les
/// gestes qu'il autorise.
///
/// POURQUOI UNE FEUILLE ET PLUS UN LANCEMENT DIRECT. Une case ne répondait
/// qu'à un geste — lancer — et n'en disait rien ; celle de quelqu'un qui
/// s'était entraîné hors calendrier restait rouge sans recours. La feuille
/// rend visible ce que la case sait : ce qui était prévu, ce qui a été fait,
/// et ce qu'on peut encore corriger.
Future<CalendarDayAction?> showProgramCalendarDaySheet(
  BuildContext context, {
  required ProgramCalendarDay day,
}) {
  return showAppSheet<CalendarDayAction>(
    context,
    builder: (_) => ProgramCalendarDaySheet(day: day),
  );
}

/// Le contenu de la feuille. PUBLIC pour que la galerie et les épreuves
/// puissent la viser au type plutôt qu'à un texte qui bouge.
class ProgramCalendarDaySheet extends ConsumerWidget {
  const ProgramCalendarDaySheet({required this.day, super.key});

  final ProgramCalendarDay day;

  /// Les séances TERMINÉES de ce jour civil, telles que l'appareil les
  /// connaît.
  ///
  /// Le jour civil LOCAL, par ses composantes : une séance commencée à
  /// 23 h 30 appartient au jour où on s'y est mis, et une différence
  /// d'heures dirait le contraire.
  List<WorkoutHistoryEntry> _sessionsDuJour(List<WorkoutHistoryEntry> tout) {
    final cible = day.localDate;
    return [
      for (final entry in tout)
        if (entry.session.status == WorkoutStatus.completed)
          if (_memeJour(entry.session.startedAt.toLocal(), cible)) entry,
    ];
  }

  static bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historique = ref.watch(workoutHistoryProvider).valueOrNull;
    final duJour = _sessionsDuJour(historique ?? const []);
    // Une séance pas encore remontée au serveur ne peut pas être reconnue
    // par lui : on ne la propose pas, on le DIT.
    final enAttente = duJour
        .where((entry) => entry.session.syncState != LocalSyncState.synced)
        .length;
    final proposables = duJour
        .where(
          (entry) =>
              entry.session.syncState == LocalSyncState.synced &&
              entry.session.id != day.sessionId,
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatLongDateMono(day.localDate),
            style: AppTypography.subheading.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _etat,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (day.isLaunchable) ...[
            AppButton(
              label: 'Lancer la séance',
              icon: AppIcons.workout,
              isExpanded: true,
              onPressed: () => Navigator.of(context).pop(const LaunchDay()),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (day.sessionId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.link_off_rounded,
                color: AppColors.darkTextTertiary,
              ),
              title: const Text('Ce n’est pas cette séance'),
              subtitle: const Text(
                'La case redevient à faire. La séance, elle, reste au journal.',
              ),
              onTap: () =>
                  Navigator.of(context).pop(const UnlinkSessionFromDay()),
            ),
          if (_accepteUneSeance) ...[
            const AppSectionLabel('Déjà fait ce jour-là ?'),
            if (historique == null)
              const AppLoadingIndicator(label: 'Lecture de tes séances')
            else if (proposables.isEmpty)
              Text(
                enAttente > 0
                    ? 'Une séance de ce jour n’est pas encore synchronisée : '
                          'elle pourra être reconnue dès son envoi.'
                    : 'Aucune séance terminée ce jour-là sur cet appareil. '
                          'Une séance faite un AUTRE jour ne coche pas cette '
                          'case : c’est la case qu’il faut déplacer.',
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              )
            else
              for (final entry in proposables)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                  ),
                  title: Text(entry.session.name ?? 'Séance libre'),
                  subtitle: Text(_resume(entry)),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(LinkSessionToDay(entry.session.id)),
                ),
          ],
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }

  /// Quand la case peut encore reconnaître une séance.
  ///
  /// Trois exclusions, chacune pour sa raison :
  ///  - une case de REPOS ne se coche pas — `rest` l'emporte sur `done` à
  ///    l'affichage, donc la reconnaissance y serait invisible, et le
  ///    serveur la refuse pour le même motif ;
  ///  - une case DÉJÀ honorée n'a rien à reconnaître de plus : le seul
  ///    geste qui a du sens y est de la détacher, et proposer les deux en
  ///    même temps ferait lire « aucune séance ce jour-là » juste sous une
  ///    case verte ;
  ///  - une case d'AVANT le départ n'a jamais été promise.
  bool get _accepteUneSeance =>
      !day.isRest &&
      day.id != null &&
      day.status != ProgramDayStatus.done &&
      day.status != ProgramDayStatus.before;

  String get _etat => switch (day.status) {
    ProgramDayStatus.done => 'Séance faite. La case est honorée.',
    ProgramDayStatus.missed =>
      'Rien que le calendrier sache n’a été fait ce jour-là.',
    ProgramDayStatus.rest => 'Repos prévu. Le repos fait partie du plan.',
    ProgramDayStatus.before => 'Avant le début du programme.',
    ProgramDayStatus.free => 'Rien n’était prévu ce jour-là.',
    ProgramDayStatus.upcoming => day.label ?? 'Séance prévue.',
  };

  String _resume(WorkoutHistoryEntry entry) {
    final duree = entry.session.durationSeconds;
    final series = '${entry.setsCount} séries';
    return duree == null
        ? series
        : '$series · ${formatDurationShort(duree).toLowerCase()}';
  }
}
