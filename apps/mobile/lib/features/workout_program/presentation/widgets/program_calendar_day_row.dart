import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/program.dart';
import '../../domain/entities/program_calendar.dart';

/// Une journée du calendrier daté : sa date, ce qui y était prévu, et ce
/// qu'il en est advenu.
///
/// L'état vient du SERVEUR — « fait », « manqué », « hors période » — et
/// l'écran se contente de lui donner une couleur. Rien n'est recalculé ici :
/// l'appareil ne connaît ni le fuseau retenu, ni les séances liées.
class ProgramCalendarDayRow extends StatelessWidget {
  const ProgramCalendarDayRow({
    required this.day,
    required this.isToday,
    required this.onTap,
    super.key,
  });

  final ProgramCalendarDay day;
  final bool isToday;

  /// `null` sur un jour qui n'attend rien : une ligne qui répond au doigt
  /// sans rien faire se lit comme un défaut.
  final VoidCallback? onTap;

  /// Ce que chaque état MONTRE. Le vert dit « fait », le rouge « manqué » —
  /// et rien d'autre n'est peint en rouge, pour que la couleur garde son
  /// sens. Les jours d'avant le départ et les jours vides restent gris :
  /// personne n'a rien promis ces jours-là.
  (String, Color, IconData?) get _apparence => switch (day.status) {
    ProgramDayStatus.done => (
      day.label ?? 'Séance faite',
      AppColors.success,
      AppIcons.checkCircle,
    ),
    ProgramDayStatus.missed => (
      day.label ?? 'Séance manquée',
      AppColors.danger,
      AppIcons.dayMissed,
    ),
    ProgramDayStatus.rest => (
      day.label ?? 'Repos',
      AppColors.darkTextSecondary,
      AppIcons.restDay,
    ),
    ProgramDayStatus.before => (
      day.label ?? 'Avant le départ',
      AppColors.darkTextTertiary,
      AppIcons.dayUpcoming,
    ),
    ProgramDayStatus.free => (
      'Rien de prévu',
      AppColors.darkTextTertiary,
      null,
    ),
    ProgramDayStatus.upcoming => (
      day.label ?? 'À venir',
      AppColors.darkTextPrimary,
      day.templateId == null ? AppIcons.trainingDay : AppIcons.workout,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _apparence;
    final date = day.localDate;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    programDayLabels[day.dayOfWeek - 1],
                    style: AppTypography.labelMono.copyWith(
                      // AUJOURD'HUI se repère d'un coup d'œil : c'est la
                      // seule ligne que l'on cherche en ouvrant l'écran.
                      color: isToday
                          ? AppColors.primaryLight
                          : AppColors.darkTextTertiary,
                    ),
                  ),
                  Text(
                    '${date.day.toString().padLeft(2, '0')}/'
                    '${date.month.toString().padLeft(2, '0')}',
                    style: AppTypography.label.copyWith(
                      color: isToday
                          ? AppColors.primaryLight
                          : AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(color: color),
              ),
            ),
            if (onTap != null)
              const Icon(
                AppIcons.startDay,
                size: 20,
                color: AppColors.primaryLight,
              ),
          ],
        ),
      ),
    );
  }
}
