import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/program.dart';
import '../../domain/entities/program_calendar.dart';

/// Une journée du calendrier daté, en carte : sa date, ce qui y était
/// prévu, ce qu'il en est advenu — et, AUJOURD'HUI, de quoi lancer la séance.
///
/// L'état vient du SERVEUR — « fait », « manqué », « hors période » — et
/// l'écran se contente de lui donner une forme et une couleur. Rien n'est
/// recalculé ici : l'appareil ne connaît ni le fuseau retenu, ni les séances
/// liées.
class ProgramCalendarDayRow extends StatelessWidget {
  const ProgramCalendarDayRow({
    required this.day,
    required this.isToday,
    required this.onTap,
    this.onStart,
    super.key,
  });

  final ProgramCalendarDay day;
  final bool isToday;

  /// `null` sur un jour qui n'attend rien : une carte qui répond au doigt
  /// sans rien faire se lit comme un défaut.
  final VoidCallback? onTap;

  /// Le bouton « Démarrer la séance », donné par l'écran au seul jour
  /// d'aujourd'hui qui attend une séance. Les autres jours se lancent depuis
  /// leur feuille, qui dit d'abord ce qu'elle sait.
  final VoidCallback? onStart;

  /// Ce que chaque état MONTRE : un titre, une mention, une icône. Le vert
  /// dit « fait », le rouge « manqué » — et rien d'autre n'est peint en
  /// rouge, pour que la couleur garde son sens.
  (String, String?, Color, IconData, Color) get _apparence =>
      switch (day.status) {
        ProgramDayStatus.done => (
          day.label ?? 'Séance',
          'Terminée',
          AppColors.success,
          AppIcons.checkCircle,
          AppColors.success,
        ),
        ProgramDayStatus.missed => (
          day.label ?? 'Séance',
          'Manquée',
          AppColors.danger,
          AppIcons.dayMissed,
          AppColors.danger,
        ),
        ProgramDayStatus.rest => (
          day.label ?? 'Repos',
          null,
          AppColors.darkTextSecondary,
          AppIcons.restDay,
          AppColors.darkTextTertiary,
        ),
        ProgramDayStatus.before => (
          day.label ?? 'Séance',
          'Avant le départ',
          AppColors.darkTextTertiary,
          AppIcons.dayUpcoming,
          AppColors.darkIconInactive,
        ),
        ProgramDayStatus.free => (
          'Rien de prévu',
          null,
          AppColors.darkTextSecondary,
          AppIcons.uncheckedCircle,
          AppColors.darkIconInactive,
        ),
        ProgramDayStatus.upcoming => (
          day.label ?? 'Séance',
          // Aujourd'hui se dit par la mention au-dessus du titre.
          isToday ? null : 'À venir',
          AppColors.darkTextSecondary,
          day.templateId == null ? AppIcons.trainingDay : AppIcons.workout,
          AppColors.primaryLight,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final (title, mention, mentionColor, icon, iconColor) = _apparence;
    final date = day.localDate;
    final dateColor = isToday
        ? AppColors.primaryLight
        : AppColors.darkTextSecondary;
    final start = onStart;

    return Semantics(
      container: true,
      button: onTap != null ? true : null,
      child: Material(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgAll,
          child: Ink(
            decoration: BoxDecoration(
              color: isToday ? AppColors.primaryCardSoft : null,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: isToday ? AppColors.primary : AppColors.darkBorder,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 52),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              programDayLabels[day.dayOfWeek - 1],
                              style: AppTypography.label.copyWith(
                                color: dateColor,
                              ),
                            ),
                            Text(
                              '${date.day.toString().padLeft(2, '0')}/'
                              '${date.month.toString().padLeft(2, '0')}',
                              style: AppTypography.body.copyWith(
                                color: dateColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(
                        width: AppSpacing.lg,
                        thickness: 1,
                        color: AppColors.rowDivider,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _Heading(
                                    title: title,
                                    mention: mention,
                                    mentionColor: mentionColor,
                                    isToday: isToday,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Icon(icon, size: 28, color: iconColor),
                              ],
                            ),
                            if (start != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              AppCtaButton(
                                label: 'Démarrer la séance',
                                icon: AppIcons.play,
                                glow: false,
                                onPressed: start,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.mention,
    required this.mentionColor,
    required this.isToday,
  });

  final String title;
  final String? mention;
  final Color mentionColor;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final mention = this.mention;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isToday)
          Text(
            'AUJOURD’HUI',
            style: AppTypography.labelMono.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        if (mention != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            mention,
            style: AppTypography.label.copyWith(color: mentionColor),
          ),
        ],
      ],
    );
  }
}
