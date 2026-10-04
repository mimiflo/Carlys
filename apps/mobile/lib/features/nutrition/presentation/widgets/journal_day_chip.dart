import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/civil_days.dart';
import '../../../../core/utilities/current_day.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../providers/journal_day_provider.dart';

/// Le jour de la page, en pastille : « Aujourd'hui », « Hier »… Le toucher
/// ouvre le calendrier, jusqu'à un an en arrière et jamais après
/// aujourd'hui : le serveur refuse un repas à venir.
///
/// Les objectifs, le journal et les ajouts suivent ce jour — consulter mardi
/// puis ajouter, c'est ajouter à mardi.
class JournalDayChip extends ConsumerWidget {
  const JournalDayChip({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref, DateTime day) async {
    // Le MÊME aujourd'hui que celui d'où le journal compte son écart.
    final today = ref.read(currentDayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: today.subtract(const Duration(days: journalMaxDaysBack)),
      lastDate: today,
      helpText: 'Jour du journal',
    );
    if (picked == null || !context.mounted) return;
    // En jours CIVILS : la veille du passage à l'heure d'été n'est qu'à
    // 23 heures, et une différence en heures la ramenait à aujourd'hui.
    ref.read(journalDayOffsetProvider.notifier).state = joursCivilsEntre(
      today,
      picked,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(journalDayProvider);
    final label = formatSpokenDay(day, ref.watch(currentDayProvider));
    return Semantics(
      button: true,
      label: 'Jour affiché : $label. Changer de jour',
      // Le nœud remplace ceux de l'InkWell : il porte donc le geste.
      onTap: () => _pick(context, ref, day),
      excludeSemantics: true,
      child: Material(
        color: AppColors.darkSurfaceAlt,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.darkBorder),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => _pick(context, ref, day),
          // Bornée par l'écran : posée dans une rangée qui ne la borne pas
          // (les actions d'en-tête), la pastille coupe son libellé en grand
          // texte plutôt que de déborder.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: AppSpacing.touchTarget,
              maxWidth: MediaQuery.sizeOf(context).width - 2 * AppSpacing.md,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.calendar, color: AppColors.primaryLight),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  const Icon(AppIcons.choose, color: AppColors.primaryLight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
