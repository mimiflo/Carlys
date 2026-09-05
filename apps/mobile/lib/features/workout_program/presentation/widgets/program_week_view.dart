import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/program.dart';

/// Une semaine du calendrier : sept lignes LUN → DIM, chacune éditable.
class ProgramWeekView extends StatelessWidget {
  const ProgramWeekView({
    required this.weekNumber,
    required this.program,
    required this.onEditDay,
    super.key,
  });

  final int weekNumber;
  final ProgramDetail program;
  final ValueChanged<int> onEditDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionLabel('Semaine $weekNumber'),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          child: Column(
            children: [
              for (var dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++) ...[
                if (dayOfWeek > 1)
                  const Divider(height: AppSpacing.sm, thickness: 0.5),
                _DayRow(
                  dayOfWeek: dayOfWeek,
                  day: program.dayAt(weekNumber, dayOfWeek),
                  onTap: () => onEditDay(dayOfWeek),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.dayOfWeek,
    required this.day,
    required this.onTap,
  });

  final int dayOfWeek;
  final ProgramDayEntry? day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = day;
    final (String label, Color color, IconData icon) = switch (entry) {
      null => ('À planifier', AppColors.darkTextTertiary, Icons.add_rounded),
      ProgramDayEntry(isRest: true) => (
        entry.label,
        AppColors.darkTextSecondary,
        Icons.bedtime_outlined,
      ),
      ProgramDayEntry(templateId: final id?) when id.isNotEmpty => (
        entry.label,
        AppColors.darkTextPrimary,
        AppIcons.workout,
      ),
      _ => (
        entry.label,
        AppColors.darkTextPrimary,
        Icons.directions_run_rounded,
      ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                programDayLabels[dayOfWeek - 1],
                style: AppTypography.labelMono.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
            ),
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
