import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../progression/domain/reward_engine.dart';
import '../../domain/entities/progress.dart';

/// Une ligne de la frise : son icône, ce qui s'est passé, et quand.
///
/// Les FRANCHISSEMENTS se distinguent à l'œil — icône et détail en violet,
/// bordure accentuée. Une frise où tout se ressemble n'est qu'un journal
/// d'événements ; ce qu'elle raconte, ce sont les jours où quelque chose a
/// basculé.
class TimelineRow extends StatelessWidget {
  const TimelineRow({required this.event, super.key});

  final ProgressEvent event;

  @override
  Widget build(BuildContext context) {
    final (icone, titre, detail) = _lire(event);
    final franchissement = event.kind.isMilestone;
    final teinte = franchissement
        ? AppColors.primaryLight
        : AppColors.darkTextSecondary;

    return Semantics(
      label:
          '${formatShortDateMono(event.occurredAt.toLocal())}, $titre'
          '${detail == null ? '' : ', $detail'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.gapRow,
        ),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.statTileAll,
          border: Border.all(
            color: franchissement
                ? AppColors.primaryBadgeBorder
                : AppColors.darkBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icone, size: 18, color: teinte),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      detail,
                      style: AppTypography.label.copyWith(color: teinte),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatShortDateMono(event.occurredAt.toLocal()),
              style: AppTypography.resized(
                AppTypography.labelMono,
                10,
              ).copyWith(color: AppColors.darkTextTertiary),
            ),
          ],
        ),
      ),
    );
  }

  /// Icône, titre et détail d'un événement.
  ///
  /// Tout vient du `payload` servi avec la ligne : la frise n'interroge rien
  /// d'autre pour s'écrire, et une page lue reste lisible hors ligne.
  static (IconData, String, String?) _lire(ProgressEvent event) {
    switch (event.kind) {
      case ProgressEventKind.session:
        final series = event.number('setsCount')?.toInt() ?? 0;
        final volume = formatVolume((event.number('volumeKg') ?? 0).toDouble());
        return (
          AppIcons.workout,
          event.text('name') ?? 'Séance',
          '$series ${series > 1 ? 'séries' : 'série'} · '
              '${volume.value} ${volume.unit}',
        );
      case ProgressEventKind.measure:
        final valeur = (event.number('value') ?? 0).toDouble();
        final poids = event.text('metricType') == 'WEIGHT_KG';
        return (
          AppIcons.bodyMetrics,
          poids ? 'Pesée' : 'Masse grasse',
          poids ? '${formatDecimal(valeur)} kg' : '${formatDecimal(valeur)} %',
        );
      case ProgressEventKind.lesson:
        final lecons = event.number('lessons')?.toInt() ?? 0;
        return (
          AppIcons.brandAcademy,
          '$lecons ${lecons > 1 ? 'leçons abordées' : 'leçon abordée'}',
          null,
        );
      case ProgressEventKind.record:
        return (
          AppIcons.record,
          event.text('exerciseName') ?? 'Record',
          _record(event),
        );
      case ProgressEventKind.reward:
        return (AppIcons.medal, _nomme(event) ?? 'Récompense obtenue', null);
      case ProgressEventKind.title:
        return (AppIcons.rank, _nomme(event) ?? 'Nouveau titre', null);
    }
  }

  /// Le nom du franchissement, retrouvé dans le CATALOGUE embarqué.
  ///
  /// Le serveur ne stocke que la clé — et c'est voulu : le libellé est du
  /// contenu éditorial, il change avec l'application, et le figer en base
  /// ferait vieillir les anciennes lignes. `null` quand la clé vient d'une
  /// version plus récente ; la ligne retombe alors sur son titre générique
  /// plutôt que de disparaître.
  static String? _nomme(ProgressEvent event) {
    final key = event.text('key');
    if (key == null) {
      return null;
    }
    for (final rule in rewardCatalog) {
      if (rule.reward.id == key) {
        return rule.reward.label;
      }
    }
    return null;
  }

  /// « 85 kg », « 12 répétitions », « 700 kg sur une série ».
  static String? _record(ProgressEvent event) {
    final valeur = (event.number('value') ?? 0).toDouble();
    return switch (event.text('recordType')) {
      'MAX_WEIGHT' => '${formatDecimal(valeur)} kg',
      'MAX_REPS' => '${formatThousands(valeur)} répétitions',
      'MAX_SET_VOLUME' => '${formatThousands(valeur)} kg sur une série',
      _ => null,
    };
  }
}
