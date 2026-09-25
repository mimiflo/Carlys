import 'package:flutter/material.dart';

import '../../../../../core/utilities/formatting.dart';
import '../../../../../design_system/design_system.dart';

/// QUAND le repas a été mangé : le jour et l'heure, deux pastilles sobres
/// sous le moment de la journée.
///
/// Un repas se journalise souvent APRÈS coup — le soir pour le midi, le
/// lendemain pour la veille. Sans elles, l'instant de SAISIE ferait foi : le
/// repas d'hier compterait dans les calories d'aujourd'hui, et rien ne
/// permettrait de le rattraper. La maquette ne les montre pas ; on ne retire
/// pas une fonction pour autant.
class MealWhenRow extends StatelessWidget {
  const MealWhenRow({
    required this.eatenAt,
    required this.onChanged,
    super.key,
  });

  /// L'instant du repas, en heure LOCALE.
  final DateTime eatenAt;
  final ValueChanged<DateTime> onChanged;

  /// Deux ans en arrière : de quoi rattraper un historique, sans ouvrir un
  /// calendrier infini. Aucune date future — le serveur les refuse, et un
  /// repas qu'on n'a pas encore mangé n'est pas un repas.
  static const int _yearsBack = 2;

  Future<void> _pickDay(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: eatenAt.isAfter(now) ? now : eatenAt,
      firstDate: DateTime(now.year - _yearsBack),
      lastDate: now,
      helpText: 'Jour du repas',
    );
    if (picked == null) {
      return;
    }
    onChanged(
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        eatenAt.hour,
        eatenAt.minute,
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(eatenAt),
      helpText: 'Heure du repas',
    );
    if (picked == null) {
      return;
    }
    onChanged(
      DateTime(
        eatenAt.year,
        eatenAt.month,
        eatenAt.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = formatSpokenDay(eatenAt, DateTime.now());
    final clock = formatClock(eatenAt);
    return Wrap(
      spacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Les deux pastilles se disent déjà « Jour du repas », « Heure du
        // repas » : le mot seul, lu à part, ne dirait rien de plus.
        ExcludeSemantics(
          child: Text(
            'Mangé',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
        Semantics(
          container: true,
          label: 'Jour du repas : $day',
          excludeSemantics: true,
          button: true,
          onTap: () => _pickDay(context),
          child: AppPill(
            label: day,
            icon: AppIcons.date,
            onTap: () => _pickDay(context),
          ),
        ),
        Semantics(
          container: true,
          label: 'Heure du repas : $clock',
          excludeSemantics: true,
          button: true,
          onTap: () => _pickTime(context),
          child: AppPill(
            label: clock,
            icon: AppIcons.time,
            onTap: () => _pickTime(context),
          ),
        ),
      ],
    );
  }
}
