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
                // Un filet sans marge : la ligne porte déjà sa hauteur de
                // cible tactile, l'écart n'a plus à la fabriquer.
                if (dayOfWeek > 1) const Divider(height: 1, thickness: 0.5),
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
    // L'icône dit la NATURE du jour (séance violette, activité libre orange,
    // repos et case vide éteints) ; le chevron, qu'il y a quelque chose à
    // faire ce jour-là (séance ou activité libre).
    final (
      String label,
      Color ink,
      Color tint,
      IconData icon,
    ) = switch (entry) {
      null => (
        'À planifier',
        AppColors.darkTextTertiary,
        AppColors.darkTextTertiary,
        AppIcons.add,
      ),
      ProgramDayEntry(isRest: true) => (
        entry.label,
        AppColors.darkTextSecondary,
        AppColors.darkTextTertiary,
        AppIcons.restDay,
      ),
      ProgramDayEntry(templateId: final id?) when id.isNotEmpty => (
        entry.label,
        AppColors.darkTextPrimary,
        AppColors.primaryLight,
        AppIcons.workout,
      ),
      _ => (
        entry.label,
        AppColors.darkTextPrimary,
        AppColors.accent,
        AppIcons.trainingDay,
      ),
    };
    final isSession = entry != null && !entry.isRest;

    // Une cible de 48 points annoncée comme un bouton : la ligne de 27
    // points qu'elle était se visait mal entre ses deux voisines, et le
    // lecteur d'écran n'y entendait pas de geste.
    return Semantics(
      container: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
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
                Icon(icon, size: 18, color: tint),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(color: ink),
                  ),
                ),
                if (isSession)
                  const Icon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: AppColors.darkTextTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
