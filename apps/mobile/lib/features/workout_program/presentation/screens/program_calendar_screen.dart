import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/feedback/server_gesture.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../../workout_session/presentation/widgets/resume_workout_confirm.dart';
import '../../../workout_template/presentation/controllers/workout_template_controllers.dart';
import '../../domain/entities/program.dart';
import '../../domain/entities/program_calendar.dart';
import '../controllers/program_controllers.dart';
import '../widgets/program_calendar_day_row.dart';
import '../widgets/program_calendar_day_sheet.dart';
import '../widgets/program_week_navigator.dart';
import '../widgets/program_week_summary.dart';

/// LE CALENDRIER DATÉ : le programme posé sur de vraies dates.
///
/// L'écran de détail dit ce qui est prévu (semaine N, jour J) ; celui-ci dit
/// QUAND, et ce qu'il en est advenu. Il ne calcule aucun état : le serveur
/// sait seul quel jour on est dans le fuseau de la personne et quelle séance
/// honore quelle case.
///
/// Lancer une séance depuis une case lui passe l'identifiant du jour — c'est
/// ce lien, et lui seul, qui fera dire « fait » à la case. Le lancement reste
/// une transaction LOCALE : il marche hors ligne, calendrier compris.
class ProgramCalendarScreen extends ConsumerStatefulWidget {
  const ProgramCalendarScreen({required this.programId, super.key});

  final String programId;

  @override
  ConsumerState<ProgramCalendarScreen> createState() =>
      _ProgramCalendarScreenState();
}

class _ProgramCalendarScreenState extends ConsumerState<ProgramCalendarScreen> {
  /// `null` tant que personne n'a navigué : le serveur ouvre alors sur la
  /// semaine d'AUJOURD'HUI, qu'il est le seul à connaître.
  int? _week;

  /// Ouvre la feuille de la case, puis exécute le geste choisi.
  ///
  /// La case ne lance plus directement : elle DIT d'abord ce qu'elle sait —
  /// ce qui était prévu, ce qui a été fait — puis propose. C'est ce qui rend
  /// atteignable la correction de celui qui s'est entraîné hors calendrier,
  /// et dont la case restait rouge sans recours.
  Future<void> _openDay(ProgramCalendarDay day) async {
    final geste = await showProgramCalendarDaySheet(context, day: day);
    if (geste == null || !mounted) {
      return;
    }
    switch (geste) {
      case LaunchDay():
        await _start(day);
      case LinkSessionToDay(:final sessionId):
        await _link(day, sessionId);
      case UnlinkSessionFromDay():
        await _link(day, null);
      case MoveDayTo(:final dayOfWeek):
        await _move(day, dayOfWeek);
    }
  }

  /// Déplace la case vers un autre jour de la même semaine.
  ///
  /// Le message nomme le jour d'ARRIVÉE et rien d'autre : dire « échangée
  /// avec le jeudi » obligerait l'écran à savoir ce que le serveur avait ce
  /// jour-là, alors qu'il vient justement de le relire. La grille, elle, se
  /// réaffiche derrière et montre le résultat.
  Future<void> _move(ProgramCalendarDay day, int dayOfWeek) async {
    await runServerGesture(context, () async {
      await ref
          .read(programActionsProvider)
          .moveDay(
            widget.programId,
            weekNumber: day.weekNumber,
            fromDayOfWeek: day.dayOfWeek,
            toDayOfWeek: dayOfWeek,
          );
      return 'Déplacée au ${programDayLabels[dayOfWeek - 1].toLowerCase()}.';
    }, scope: 'program-calendar');
  }

  /// Fait reconnaître (ou oublier) une séance par la case.
  ///
  /// Le serveur refuse ce qui n'est pas vrai : une séance d'un autre jour,
  /// une case de repos. La feuille ne propose déjà que du vrai, donc ces
  /// refus ne se voient qu'en cas de course — d'où le filet partagé du
  /// dépôt, qui distingue au moins la panne du hors-ligne.
  Future<void> _link(ProgramCalendarDay day, String? sessionId) async {
    final dayId = day.id;
    if (dayId == null) {
      return;
    }
    await runServerGesture(context, () async {
      await ref
          .read(programActionsProvider)
          .linkCalendarSession(
            programId: widget.programId,
            dayId: dayId,
            sessionId: sessionId,
          );
      return sessionId == null
          ? 'Case libérée : elle redevient à faire.'
          : 'Case cochée : la séance de ce jour la remplit.';
    }, scope: 'program-calendar');
  }

  Future<void> _start(ProgramCalendarDay day) async {
    final templateId = day.templateId;
    if (templateId == null) {
      return;
    }
    if (ref.read(activeWorkoutProvider).valueOrNull != null) {
      // Le domaine impose AU PLUS UNE séance en cours : on ne remplace
      // jamais celle qui tourne, on propose de la reprendre.
      final reprendre = await showResumeWorkoutConfirm(context);
      if (reprendre && mounted) {
        await context.push(AppRoutes.activeWorkout);
      }
      return;
    }
    try {
      await ref
          .read(workoutTemplateActionsProvider)
          .start(templateId, programDayId: day.id);
    } on StateError {
      // Course rare : une séance a démarré entre-temps. Rien n'est perdu, on
      // renvoie simplement vers elle.
    }
    if (mounted) {
      await context.push(AppRoutes.activeWorkout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semaine = ref.watch(
      programCalendarProvider((programId: widget.programId, week: _week)),
    );

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: semaine.when(
          loading: () =>
              const AppLoadingIndicator(label: 'Chargement du calendrier'),
          error: (error, _) => ConnectionAwareError(
            error: error,
            title: 'Calendrier indisponible',
            message:
                'Ce programme n’a peut-être pas encore de date de début : '
                'choisis-en une depuis sa fiche.',
            offlineMessage:
                'Le calendrier vit sur le serveur : il revient avec le '
                'réseau.',
            onRetry: () => ref.invalidate(programCalendarProvider),
          ),
          data: (calendrier) => ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.gutter,
              AppSpacing.gutter,
              AppSpacing.gutter + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      calendrier.name,
                      style: AppTypography.pageTitle.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ProgramWeekNavigator(
                week: calendrier,
                onWeek: (value) => setState(() => _week = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    for (final jour in calendrier.days) ...[
                      if (jour.dayOfWeek > 1)
                        const Divider(height: AppSpacing.sm, thickness: 0.5),
                      ProgramCalendarDayRow(
                        day: jour,
                        isToday: jour.date == calendrier.today,
                        // Une case VIDE ne répond pas : une ligne qui répond
                        // au doigt sans rien faire se lit comme un défaut.
                        onTap: jour.id == null ? null : () => _openDay(jour),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.gapRow),
              ProgramWeekSummary(week: calendrier),
            ],
          ),
        ),
      ),
    );
  }
}
