import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import 'correct_set_sheet.dart';

/// Une série d'une séance TERMINÉE : lisible, corrigeable, supprimable.
///
/// Extraite de `workout_detail_screen.dart`, qui tenait la carte en ligne :
/// lui ajouter les deux gestes et leurs états l'aurait poussé au-delà de la
/// limite de 250 lignes d'un widget.
///
/// La ligne ENTIÈRE ouvre la correction, comme une tuile explicable ouvre son
/// explication : poser un bouton d'édition à côté des chiffres créerait deux
/// cibles concurrentes pour une seule intention.
class FinishedSetRow extends ConsumerWidget {
  const FinishedSetRow({required this.sessionId, required this.set, super.key});

  final String sessionId;
  final WorkoutSetEntry set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        button: true,
        label: '${set.exerciseName}, ${_valeurEnToutesLettres(set)}. Corriger',
        // Relais des actions : `excludeSemantics` masque celles de
        // l'InkWell — corriger au tap, supprimer à l'appui long.
        onTap: () => _corriger(context, ref),
        onLongPress: () => _supprimer(context, ref),
        excludeSemantics: true,
        child: InkWell(
          onTap: () => _corriger(context, ref),
          onLongPress: () => _supprimer(context, ref),
          borderRadius: AppRadius.cardSecondaryAll,
          child: AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(set.exerciseName, style: theme.textTheme.bodyLarge),
                      if (plannedLabel(set) != null)
                        Text(
                          plannedLabel(set)!,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (set.kind != SetKind.normal) ...[
                  AppBadge(label: set.kind.label),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  _valeur(set),
                  style: AppTypography.resized(
                    AppTypography.metric,
                    16,
                  ).copyWith(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _corriger(BuildContext context, WidgetRef ref) async {
    final correction = await showCorrectSetSheet(context, set);
    if (correction == null || !context.mounted) {
      return;
    }
    await _ecrire(
      context,
      () => ref
          .read(workoutActionsProvider)
          .correctSet(
            sessionId,
            set.id,
            reps: correction.reps,
            weightKg: correction.weightKg,
          ),
      succes: 'Série corrigée.',
    );
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final confirme = await showAppConfirm(
      context,
      title: 'Supprimer cette série ?',
      // La conséquence, pas seulement le geste : c'est ce qui distingue
      // une confirmation utile d'un « êtes-vous sûr » décoratif.
      message:
          '${set.exerciseName}, ${_valeur(set)}. Tes records et tes '
          'statistiques seront recalculés sans elle.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!confirme || !context.mounted) {
      return;
    }
    await _ecrire(
      context,
      () => ref
          .read(workoutActionsProvider)
          .removeSetFromFinished(sessionId, set.id),
      succes: 'Série supprimée.',
    );
  }

  /// L'écriture est LOCALE puis mise en file : elle aboutit hors ligne. Seule
  /// une panne de la base locale peut échouer, et elle doit se voir.
  Future<void> _ecrire(
    BuildContext context,
    Future<void> Function() geste, {
    required String succes,
  }) async {
    final notices = AppNotices.of(context);
    try {
      await geste();
      notices.show(succes, tone: AppNoticeTone.success);
    } on AppException catch (error) {
      notices.show(error.message, tone: AppNoticeTone.error);
    }
  }
}

/// « 5 × 200 kg », jamais « 5 × 200.0 kg ».
///
/// Le point décimal d'un `double` brut passait tel quel dans l'ancienne carte
/// de l'écran de détail, d'où elle est extraite : une charge ronde s'affichait
/// avec un zéro superflu, et un point là où le dépôt écrit une virgule. La
/// ligne d'à côté, celle du lecteur d'écran, formatait déjà correctement.
String _valeur(WorkoutSetEntry set) => [
  if (set.reps != null) formatThousands(set.reps!),
  if (set.weightKg != null) '${formatDecimal(set.weightKg!)} kg',
].join(' × ');

/// La même valeur, dite pour un lecteur d'écran : « × » ne se prononce pas.
String _valeurEnToutesLettres(WorkoutSetEntry set) => [
  if (set.reps != null) '${set.reps} répétitions',
  if (set.weightKg != null) '${formatDecimal(set.weightKg!)} kilos',
].join(', ');

/// « Prévu 8 × 60 kg » — la cible AFFICHÉE au moment de la validation.
///
/// Elle est stockée sur la série elle-même : l'écart prévu/réalisé reste
/// consultable des mois plus tard, indépendamment du modèle d'origine.
String? plannedLabel(WorkoutSetEntry set) {
  final reps = set.plannedReps;
  final weight = set.plannedWeightKg;
  if (reps == null && weight == null) {
    return null;
  }
  final parts = [
    if (reps != null) formatThousands(reps),
    if (weight != null) '${formatDecimal(weight)} kg',
  ];
  return 'Prévu ${parts.join(' × ')}';
}
