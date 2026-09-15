import 'package:flutter/material.dart';

import '../../../../core/explanations/explanation.dart';
import '../../../../core/explanations/explanation_sheet.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';
import '../../domain/title_explanations.dart';

/// « Comprendre les titres » : l'échelle entière, et ce que chaque palier veut
/// dire.
///
/// L'application affichait « Apprenti » et « 4 / 5 PALIERS » sans qu'aucune
/// surface ne dise ce que ces mots signifient. Elle montrait le palier porté
/// et le suivant, jamais le chemin complet : impossible de savoir combien il
/// y en a, ni ce qui les sépare, ni ce qu'un titre mesure.
///
/// Chaque palier ouvre son POURQUOI par le mécanisme du reste de
/// l'application : la ligne entière répond, le glyphe n'est qu'un ornement.
Future<void> showTitlesExplained(
  BuildContext context, {
  required CarlysTitle porte,
  required CarlysTitle grave,
}) {
  return showAppSheet<void>(
    context,
    style: AppSheetStyle.picker,
    builder: (_) => _TitlesExplainedSheet(porte: porte, grave: grave),
  );
}

class _TitlesExplainedSheet extends StatelessWidget {
  const _TitlesExplainedSheet({required this.porte, required this.grave});

  /// Le titre que le score du moment donne.
  final CarlysTitle porte;

  /// Le plus haut JAMAIS atteint, celui que l'écrin garde. Il peut être plus
  /// élevé que [porte] : c'est précisément ce que la feuille explique.
  final CarlysTitle grave;

  @override
  Widget build(BuildContext context) {
    final systeme = TitleExplanations.systeme;

    // Les marges système sont déjà prises par `showAppSheet`.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(title: systeme.titre),
            const SizedBox(height: AppSpacing.sm),
            Text(
              systeme.cequeCest,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final titre in CarlysTitle.values) ...[
                    _LignePalier(
                      titre: titre,
                      porte: titre == porte,
                      grave: titre == grave,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _Note(TitleExplanations.rang),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    systeme.cequeCaNeDitPas ?? '',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'J’ai compris',
              isExpanded: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un palier de l'échelle : son rang, son nom, son seuil, et sa porte.
class _LignePalier extends StatelessWidget {
  const _LignePalier({
    required this.titre,
    required this.porte,
    required this.grave,
  });

  final CarlysTitle titre;

  /// Celui que le score du moment donne : mis en évidence.
  final bool porte;

  /// Le plus haut jamais atteint. Quand il diffère de [porte], la feuille le
  /// dit : c'est la promesse la plus rassurante du système, et rien ne
  /// l'énonçait.
  final bool grave;

  @override
  Widget build(BuildContext context) {
    final explication = TitleExplanations.of(titre);
    final couleur = porte ? AppColors.primaryLight : AppColors.darkTextTertiary;

    return AppExplainable(
      enonce:
          '${titre.label}, palier ${titre.roman}, ${titre.threshold} points',
      surface: porte ? AppColors.darkSurface : null,
      borderRadius: AppRadius.statTileAll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.gapTile,
      ),
      onExplain: () => showExplanation(context, explication),
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.lg,
            child: Text(
              titre.roman,
              style: AppTypography.labelMono.copyWith(color: couleur),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      titre.label,
                      style: AppTypography.subheading.copyWith(
                        color: porte
                            ? AppColors.darkTextPrimary
                            : AppColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    const Icon(
                      AppIcons.info,
                      size: AppExplainButton.glyphSize,
                      color: AppColors.darkTextTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  explication.cequeCest,
                  // Deux lignes, pas plus : la feuille montre les CINQ
                  // paliers d'un coup d'œil, et une explication complète
                  // par ligne en ferait un mur. Le texte entier est à un
                  // tapotement.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${titre.threshold}',
                style: AppTypography.labelMono.copyWith(color: couleur),
              ),
              if (grave && !porte)
                Text(
                  'GRAVÉ',
                  style: AppTypography.labelMono.copyWith(
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Un paragraphe de bas de feuille, ouvert en entier d'un tapotement.
class _Note extends StatelessWidget {
  const _Note(this.explication);

  final Explanation explication;

  @override
  Widget build(BuildContext context) {
    return AppExplainable(
      enonce: explication.titre,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      onExplain: () => showExplanation(context, explication),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              AppIcons.info,
              size: AppExplainButton.glyphSize,
              color: AppColors.darkTextTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              explication.titre,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
