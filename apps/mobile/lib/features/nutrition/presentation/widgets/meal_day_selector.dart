import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../providers/journal_day_provider.dart';
import 'meal_moment_rows.dart';

/// Les deux flèches qui font reculer le journal d'un jour.
///
/// Le serveur servait l'historique depuis toujours — `GET /nutrition/meals`
/// prend deux bornes — mais l'application ne demandait QUE la journée en
/// cours : un repas oublié la veille était définitivement hors de portée,
/// puisque même la correction ne pouvait pas l'atteindre.
///
/// La flèche « demain » est désactivée sur aujourd'hui, et non masquée : une
/// commande qui disparaît laisse croire à un bug, une commande éteinte dit
/// « pas par là ».
class MealDaySelector extends ConsumerWidget {
  const MealDaySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(journalDayOffsetProvider);
    final day = ref.watch(journalDayProvider);
    final aujourdHui = offset == 0;

    void bouger(int pas) {
      ref.read(journalDayOffsetProvider.notifier).state = offset + pas;
    }

    return Row(
      children: [
        IconButton(
          onPressed: offset > -journalMaxDaysBack ? () => bouger(-1) : null,
          tooltip: 'Jour précédent',
          icon: const Icon(Icons.chevron_left_rounded),
          color: AppColors.darkTextSecondary,
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              MealMomentRows.spellDay(day, DateTime.now()),
              textAlign: TextAlign.center,
              style: AppTypography.label.copyWith(
                color: aujourdHui
                    ? AppColors.darkTextSecondary
                    : AppColors.primaryLight,
              ),
            ),
          ),
        ),
        IconButton(
          // Jamais au-delà d'aujourd'hui : le serveur refuse un repas à
          // venir, donc un jour futur n'aurait rien à montrer ni à recevoir.
          onPressed: aujourdHui ? null : () => bouger(1),
          tooltip: 'Jour suivant',
          icon: const Icon(Icons.chevron_right_rounded),
          color: AppColors.darkTextSecondary,
        ),
      ],
    );
  }
}
