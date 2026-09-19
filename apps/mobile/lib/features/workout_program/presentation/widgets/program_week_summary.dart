import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/program_calendar.dart';

/// Ce que la semaine DIT, en trois chiffres et une légende.
///
/// Sans elle, le calendrier laissait la moitié de l'écran vide et obligeait
/// à recompter les lignes pour savoir où l'on en est. Les trois nombres se
/// déduisent des cases servies — rien n'est redemandé au serveur.
///
/// La légende n'est pas décorative : le vert et le rouge portent un jugement
/// (« faite », « manquée »), et une couleur qui juge doit se nommer. Le gris
/// des jours d'avant le départ, surtout : il dit « rien ne t'était demandé »,
/// ce qu'aucune teinte ne fait comprendre seule.
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
    final prevues = faites + manquees + aVenir;
    final avantDepart = _count(ProgramDayStatus.before);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Faites',
                value: '$faites',
                // La jauge compare aux séances PRÉVUES de la semaine, pas aux
                // sept jours : un plan à trois séances serait sinon montré
                // aux deux cinquièmes alors qu'il est complet.
                progress: prevues == 0 ? 0 : faites / prevues,
                gaugeColor: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AppStatTile(
                label: 'Manquées',
                value: '$manquees',
                progress: prevues == 0 ? 0 : manquees / prevues,
                gaugeColor: AppColors.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AppStatTile(
                label: 'À venir',
                value: '$aVenir',
                progress: prevues == 0 ? 0 : aVenir / prevues,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LegendRow(
                color: AppColors.success,
                icon: Icons.check_circle_rounded,
                text: 'Séance faite : une séance terminée porte ce jour.',
              ),
              const SizedBox(height: AppSpacing.xxs),
              const _LegendRow(
                color: AppColors.danger,
                icon: Icons.remove_circle_outline_rounded,
                text: 'Séance manquée : le jour est passé, rien n’a été fait.',
              ),
              if (avantDepart > 0) ...[
                const SizedBox(height: AppSpacing.xxs),
                const _LegendRow(
                  color: AppColors.darkTextTertiary,
                  icon: Icons.schedule_rounded,
                  text:
                      'Avant le départ : ces jours précèdent ton premier '
                      'jour, ils ne te sont pas reprochés.',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
