import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/program.dart';
import '../../domain/entities/program_calendar.dart';

/// Les deux réglages d'un programme : le suivre, et le DATER.
///
/// Extraits de l'écran de détail, qui touchait son plafond de widget en les
/// portant. Ils vont ensemble : un programme suivi sans date reste une
/// grille, un programme daté sans être suivi n'apparaît nulle part ailleurs.
class ProgramSettingsCard extends StatelessWidget {
  const ProgramSettingsCard({
    required this.program,
    required this.onActive,
    required this.onStartsOn,
    required this.onOpenCalendar,
    super.key,
  });

  final ProgramDetail program;
  final ValueChanged<bool> onActive;

  /// Rend le jour civil choisi, ou `null` pour retirer la date.
  final ValueChanged<DayKey?> onStartsOn;
  final VoidCallback onOpenCalendar;

  /// Deux ans de part et d'autre : reprendre un plan commencé le mois
  /// dernier est aussi normal que commencer lundi prochain. Aucune borne de
  /// futur, donc — contrairement aux dates d'ÉVÉNEMENT (pesée, repas,
  /// séance), qu'on ne peut pas vivre à l'avance.
  static const int _yearsAround = 2;

  Future<void> _pickDate(BuildContext context) async {
    final maintenant = DateTime.now();
    final actuelle = program.startsOn;
    final choisie = await showDatePicker(
      context: context,
      initialDate: actuelle == null ? maintenant : asLocalDate(actuelle),
      firstDate: DateTime(maintenant.year - _yearsAround),
      lastDate: DateTime(maintenant.year + _yearsAround),
      helpText: 'Premier jour du programme',
    );
    if (choisie == null) {
      return;
    }
    // Une CHAÎNE `AAAA-MM-JJ`, jamais un instant : c'est un jour civil, et
    // l'envoyer en ISO 8601 complet le ferait reculer d'un jour à l'ouest de
    // Greenwich.
    final mois = choisie.month.toString().padLeft(2, '0');
    final jour = choisie.day.toString().padLeft(2, '0');
    onStartsOn('${choisie.year}-$mois-$jour');
  }

  String get _dateLisible {
    final debut = program.startsOn;
    if (debut == null) {
      return 'À choisir';
    }
    final date = asLocalDate(debut);
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final date = program.startsOn;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Programme suivi',
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              Switch(value: program.isActive, onChanged: onActive),
            ],
          ),
          AppListRow(
            title: 'Premier jour',
            trailingText: _dateLisible,
            leading: AppIcons.date,
            onTap: () => _pickDate(context),
          ),
          if (date == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                'Sans premier jour, ce plan reste une grille : choisis une '
                'date pour lui donner un calendrier, avec ses séances faites '
                'et manquées.',
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
            )
          else ...[
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Voir le calendrier',
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              onPressed: onOpenCalendar,
            ),
          ],
        ],
      ),
    );
  }
}
