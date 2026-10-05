import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/program_calendar.dart';

/// La carte d'en-tête du calendrier : le programme et toute sa période
/// (« Force en 2 semaines / Du 7 au 20 septembre 2026 »).
///
/// La fin se DÉDUIT de ce que le serveur sert : les semaines du plan partent
/// du lundi de la semaine du départ (les jours d'avant sont « avant le
/// départ »), et il y en a [ProgramCalendarWeek.weeksCount].
class ProgramCalendarHero extends StatelessWidget {
  const ProgramCalendarHero({required this.week, super.key});

  final ProgramCalendarWeek week;

  @override
  Widget build(BuildContext context) {
    final start = asLocalDate(week.startsOn);
    final monday = DateTime(
      start.year,
      start.month,
      start.day - start.weekday + 1,
    );
    final end = DateTime(
      monday.year,
      monday.month,
      monday.day + 7 * week.weeksCount - 1,
    );
    return AppCard(
      child: Row(
        children: [
          const AppIconBadge(icon: AppIcons.programOutline, size: 56),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  week.name,
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Du ${formatDayRange(start, end)}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
