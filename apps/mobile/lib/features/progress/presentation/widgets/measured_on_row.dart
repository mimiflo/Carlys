import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// La date d'une mesure, et son calendrier : la même ligne dans la feuille
/// du poids et dans celle des mensurations.
///
/// Une date est demandée parce que toute mesure était autrefois datée de
/// l'instant : on ne pouvait ni rattraper un oubli de la veille, ni
/// corriger une mesure mal datée.
class MeasuredOnRow extends StatelessWidget {
  const MeasuredOnRow({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// « Date de la pesée », « Date de la mesure ».
  final String title;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _choisir(BuildContext context) async {
    final maintenant = DateTime.now();
    // Deux ans en arrière : de quoi rattraper un historique, sans ouvrir un
    // calendrier infini — ou plus loin, jusqu'à la date d'une mesure plus
    // ancienne qu'on corrige : le calendrier refuse de s'ouvrir avant sa
    // première date permise. Aucune date future — on ne se mesure pas
    // demain, et l'API le refuse.
    final deuxAns = DateTime(maintenant.year - 2);
    final choisie = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: value.isBefore(deuxAns) ? value : deuxAns,
      lastDate: maintenant,
      helpText: title,
    );
    if (choisie != null) {
      onChanged(choisie);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: title,
      trailingText: formatSpokenDay(value, DateTime.now()),
      leading: AppIcons.date,
      onTap: () => _choisir(context),
    );
  }
}
