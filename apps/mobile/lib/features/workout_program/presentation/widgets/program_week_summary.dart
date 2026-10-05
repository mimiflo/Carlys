import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/program_calendar.dart';

/// Ce que la semaine DIT, en trois chiffres : faites, manquées, à venir.
///
/// Sans eux, il fallait recompter les lignes pour savoir où l'on en est. Ils
/// se déduisent des cases servies — rien n'est redemandé au serveur.
class ProgramWeekSummary extends StatelessWidget {
  const ProgramWeekSummary({required this.week, super.key});

  final ProgramCalendarWeek week;

  int _count(ProgramDayStatus status) =>
      week.days.where((day) => day.status == status).length;

  @override
  Widget build(BuildContext context) {
    final faites = _count(ProgramDayStatus.done);
    final manquees = _count(ProgramDayStatus.missed);
    final aVenir = _count(ProgramDayStatus.upcoming);
    return Row(
      children: [
        Expanded(
          child: _Counter(
            value: faites,
            singular: 'Faite',
            plural: 'Faites',
            icon: AppIcons.check,
            color: AppColors.success,
            background: AppColors.successBadgeBg,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _Counter(
            value: manquees,
            singular: 'Manquée',
            plural: 'Manquées',
            icon: AppIcons.minus,
            color: AppColors.danger,
            background: AppColors.dangerBadgeBg,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _Counter(
            value: aVenir,
            singular: 'À venir',
            plural: 'À venir',
            icon: AppIcons.time,
            color: AppColors.primaryLight,
            background: AppColors.primaryBadgeBg,
          ),
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.value,
    required this.singular,
    required this.plural,
    required this.icon,
    required this.color,
    required this.background,
  });

  final int value;
  final String singular;
  final String plural;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    // « 0 Manquée », « 1 Faite », « 2 Faites » : le singulier jusqu'à un.
    final label = value > 1 ? plural : singular;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      semanticLabel: '$value $label',
      child: ExcludeSemantics(
        child: Row(
          children: [
            AppIconBadge(
              icon: icon,
              color: color,
              background: background,
              size: 36,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: AppTypography.title.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  // Un mot seul (« Manquées ») : il se resserre plutôt que de
                  // finir en « Man… » sur une tuile étroite ou un texte agrandi.
                  AppWholeWordsText(
                    label,
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La légende des couleurs, sous la liste. Elle n'est pas décorative : le
/// vert et le rouge portent un jugement (« terminée », « manquée »), et une
/// couleur qui juge doit se nommer. Le gris des jours d'avant le départ ne
/// paraît que s'il est à l'écran : il dit « rien ne t'était demandé ».
class ProgramCalendarLegend extends StatelessWidget {
  const ProgramCalendarLegend({required this.week, super.key});

  final ProgramCalendarWeek week;

  @override
  Widget build(BuildContext context) {
    final avantDepart = week.days.any(
      (day) => day.status == ProgramDayStatus.before,
    );
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        const _LegendItem(color: AppColors.success, text: 'Terminée'),
        const _LegendItem(color: AppColors.danger, text: 'Manquée'),
        const _LegendItem(color: AppColors.primary, text: 'À venir'),
        const _LegendItem(color: AppColors.darkTextTertiary, text: 'Repos'),
        if (avantDepart)
          const _LegendItem(
            color: AppColors.darkIconInactive,
            text: 'Avant le départ',
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.text});

  final Color color;
  final String text;

  static const double _dot = 10;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}
