import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../../workout_template/presentation/controllers/workout_template_controllers.dart';
import '../../domain/entities/program_calendar.dart';
import '../controllers/program_controllers.dart';
import '../widgets/program_calendar_day_row.dart';
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

  Future<void> _start(ProgramCalendarDay day) async {
    final templateId = day.templateId;
    if (templateId == null) {
      return;
    }
    if (ref.read(activeWorkoutProvider).valueOrNull != null) {
      // Le domaine impose AU PLUS UNE séance en cours : on ne remplace
      // jamais celle qui tourne, on propose de la reprendre.
      final reprendre = await _confirmActiveSession();
      if (reprendre == true && mounted) {
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

  Future<bool?> _confirmActiveSession() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Une séance est en cours'),
        content: const Text('Termine-la avant d’en lancer une autre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Plus tard'),
          ),
          AppButton(
            label: 'Reprendre la séance',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
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
              _WeekNavigator(
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
                        onTap: jour.isLaunchable ? () => _start(jour) : null,
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

/// Les deux flèches et le rang de la semaine servie.
///
/// La flèche éteinte aux bornes du plan, jamais masquée : une commande qui
/// disparaît laisse croire à un défaut, une commande éteinte dit « pas par
/// là ».
class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({required this.week, required this.onWeek});

  final ProgramCalendarWeek week;
  final ValueChanged<int> onWeek;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: week.weekNumber > 1
              ? () => onWeek(week.weekNumber - 1)
              : null,
          tooltip: 'Semaine précédente',
          icon: const Icon(Icons.chevron_left_rounded),
          color: AppColors.darkTextSecondary,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'Semaine ${week.weekNumber} sur ${week.weeksCount}',
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              Text(
                week.isCurrentWeek
                    ? 'Semaine en cours'
                    : week.currentWeek == null
                    ? 'Hors de la période du plan'
                    : 'Semaine en cours : ${week.currentWeek}',
                style: AppTypography.label.copyWith(
                  color: week.isCurrentWeek
                      ? AppColors.primaryLight
                      : AppColors.darkTextTertiary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: week.weekNumber < week.weeksCount
              ? () => onWeek(week.weekNumber + 1)
              : null,
          tooltip: 'Semaine suivante',
          icon: const Icon(Icons.chevron_right_rounded),
          color: AppColors.darkTextSecondary,
        ),
      ],
    );
  }
}
