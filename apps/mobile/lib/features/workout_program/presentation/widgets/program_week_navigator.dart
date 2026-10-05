import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/program_calendar.dart';

/// Les deux flèches, le rang de la semaine servie et ses dates.
///
/// La flèche éteinte aux bornes du plan, jamais masquée : une commande qui
/// disparaît laisse croire à un défaut, une commande éteinte dit « pas par
/// là ».
class ProgramWeekNavigator extends StatelessWidget {
  const ProgramWeekNavigator({
    required this.week,
    required this.onWeek,
    super.key,
  });

  final ProgramCalendarWeek week;
  final ValueChanged<int> onWeek;

  @override
  Widget build(BuildContext context) {
    final hasPrevious = week.weekNumber > 1;
    final hasNext = week.weekNumber < week.weeksCount;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          AppRoundIconButton(
            icon: AppIcons.chevronLeft,
            tooltip: 'Semaine précédente',
            color: AppColors.darkTextSecondary,
            onPressed: hasPrevious ? () => onWeek(week.weekNumber - 1) : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Semaine ${week.weekNumber} sur ${week.weeksCount}',
                  textAlign: TextAlign.center,
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                if (week.days.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    formatDayRange(
                      week.days.first.localDate,
                      week.days.last.localDate,
                    ),
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppRoundIconButton(
            icon: AppIcons.chevronRight,
            tooltip: 'Semaine suivante',
            onPressed: hasNext ? () => onWeek(week.weekNumber + 1) : null,
          ),
        ],
      ),
    );
  }
}
