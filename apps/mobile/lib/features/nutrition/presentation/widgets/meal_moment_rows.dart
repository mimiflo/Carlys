import 'package:flutter/material.dart';

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

  /// « Aujourd'hui », « Hier », puis la date en clair : les deux jours qui
  /// couvrent la quasi-totalité des saisies se nomment, les autres se
  /// datent.
  static String spellDay(DateTime moment, DateTime now) {
    bool memeJour(DateTime other) =>
        moment.year == other.year &&
        moment.month == other.month &&
        moment.day == other.day;
    if (memeJour(now)) {
      return 'Aujourd’hui';
    }
    if (memeJour(DateTime(now.year, now.month, now.day - 1))) {
      return 'Hier';
    }
    final jour = moment.day.toString().padLeft(2, '0');
    final mois = moment.month.toString().padLeft(2, '0');
    return '$jour/$mois/${moment.year}';
  }

  /// L'heure en 24 h, comme partout ailleurs dans l'application.
  static String spellTime(DateTime moment) {
    final heures = moment.hour.toString().padLeft(2, '0');
    final minutes = moment.minute.toString().padLeft(2, '0');
    return '${heures}h$minutes';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppListRow(
          title: 'Jour du repas',
          trailingText: spellDay(eatenAt, DateTime.now()),
          leading: AppIcons.date,
          onTap: () => _pickDate(context),
        ),
        AppListRow(
          title: 'Heure du repas',
          trailingText: spellTime(eatenAt),
          leading: AppIcons.time,
          onTap: () => _pickTime(context),
        ),
      ],
    );
  }
}
