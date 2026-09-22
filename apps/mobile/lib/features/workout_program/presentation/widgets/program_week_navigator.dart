import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/program_calendar.dart';

/// Les deux flèches et le rang de la semaine servie.
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
    return Row(
      children: [
        IconButton(
          onPressed: week.weekNumber > 1
              ? () => onWeek(week.weekNumber - 1)
              : null,
          tooltip: 'Semaine précédente',
          icon: const Icon(AppIcons.chevronLeft),
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
          icon: const Icon(AppIcons.chevronRight),
          color: AppColors.darkTextSecondary,
        ),
      ],
    );
  }
}
