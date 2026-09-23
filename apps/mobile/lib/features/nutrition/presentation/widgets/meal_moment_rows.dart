import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// Quand le repas a été mangé : une date et une heure, toutes deux
/// modifiables.
///
/// Un repas se journalise souvent APRÈS coup — le soir pour le midi, le
/// lendemain pour la veille. Sans ces deux lignes, l'instant de SAISIE
/// faisait foi : le repas d'hier comptait dans les calories d'aujourd'hui,
/// et rien ne permettait de le rattraper.
class MealMomentRows extends StatelessWidget {
  const MealMomentRows({
    required this.eatenAt,
    required this.onChanged,
    super.key,
  });

  final DateTime eatenAt;
  final ValueChanged<DateTime> onChanged;

  /// Deux ans en arrière : de quoi rattraper un historique, sans ouvrir un
  /// calendrier infini. Aucune date future — le serveur les refuse, et un
  /// repas qu'on n'a pas encore mangé n'est pas un repas.
  static const int _yearsBack = 2;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: eatenAt.isAfter(now) ? now : eatenAt,
      firstDate: DateTime(now.year - _yearsBack),
      lastDate: now,
      helpText: 'Date du repas',
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
    return Column(
      children: [
        AppListRow(
          title: 'Jour du repas',
          trailingText: formatSpokenDay(eatenAt, DateTime.now()),
          leading: AppIcons.date,
          onTap: () => _pickDate(context),
        ),
        AppListRow(
          title: 'Heure du repas',
          trailingText: formatClock(eatenAt),
          leading: AppIcons.time,
          onTap: () => _pickTime(context),
        ),
      ],
    );
  }
}
