import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/program.dart';
import '../../domain/entities/program_calendar.dart';

/// La semaine d'un coup d'œil : sept pastilles, aujourd'hui en violet, un
/// point vert sous un jour fait, rouge sous un jour manqué.
///
/// Un RÉSUMÉ, pas une commande : à sept sur la largeur d'un téléphone, une
/// pastille n'atteint pas les 48 points d'une cible tactile, et la liste
/// juste dessous porte déjà chaque jour, son état et son geste. Le lecteur
/// d'écran la saute pour la même raison.
class ProgramDayStrip extends StatelessWidget {
  const ProgramDayStrip({required this.week, super.key});

  final ProgramCalendarWeek week;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (index, day) in week.days.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _DayPill(day: day, isToday: day.date == week.today),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.isToday});

  final ProgramCalendarDay day;
  final bool isToday;

  static const double _dot = 6;

  @override
  Widget build(BuildContext context) {
    final dot = switch (day.status) {
      ProgramDayStatus.done => AppColors.success,
      ProgramDayStatus.missed => AppColors.danger,
      _ => null,
    };
    final ink = isToday
        ? AppColors.darkTextPrimary
        : AppColors.darkTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: isToday ? AppColors.cta : null,
        color: isToday ? null : AppColors.darkSurface,
        borderRadius: AppRadius.mdAll,
        border: isToday ? null : Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              programDayLabels[day.dayOfWeek - 1],
              style: AppTypography.label.copyWith(color: ink),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${day.localDate.day}',
              style: AppTypography.heading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Container(
            width: _dot,
            height: _dot,
            decoration: BoxDecoration(
              color: dot ?? AppColors.backdropClear,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
