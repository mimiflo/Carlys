import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../domain/entities/nutrition.dart';
import 'dna_helix.dart';

/// Hero « métabolisme » (maquette 2g) : hélice ADN plein cadre décalée à
/// droite, halo violet, dégradés de lisibilité pour la colonne de gauche,
/// dépense totale en très grand.
class MetabolismHero extends StatelessWidget {
  const MetabolismHero({required this.metabolism, super.key});

  final MetabolismResult? metabolism;

  /// Géométrie de la maquette : hero de 378, hélice de la même hauteur
  /// débordant de 60 à droite (`root.position.x = 0.9`).
  static const double _heroHeight = 378;
  static const double _sceneRight = -60;
  static const double _helixHeight = 330;

  /// Fondu vertical de la scène (transparent → plein → transparent).
  static const List<double> _sceneFade = [0.0, 0.16, 0.62, 0.94];

  /// Halo violet de la maquette (.22) obtenu depuis le halo du design system.
  static const double _haloOpacity = 0.55;

  /// Valeur absente tant que le serveur n'a pas pu calculer le métabolisme.
  static const String _placeholder = '—';

  @override
  Widget build(BuildContext context) {
    final result = metabolism;
    final tdee = result?.tdeeKcal;
    final bmr = result?.bmrKcal;
    // Activité = dépense totale − métabolisme de base : aucune valeur inventée.
    final activity = tdee == null || bmr == null ? null : tdee - bmr;
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: _heroHeight + topInset,
      child: Stack(
        children: [
          // Halo violet de fond (radial .22 de la maquette).
          const Positioned.fill(
            child: Opacity(opacity: _haloOpacity, child: AppSceneHalo()),
          ),
          Positioned(
            top: topInset,
            right: _sceneRight,
            child: const AppSceneContainer(
              size: _heroHeight,
              opacity: 0.85,
              verticalFadeStops: _sceneFade,
              child: Center(child: DnaHelix(height: _helixHeight)),
            ),
          ),
          // Lisibilité : la colonne de texte est à gauche, le fond s'éteint
          // ensuite vers le bas.
          const Positioned.fill(child: AppSceneScrim.lateral()),
          const Positioned.fill(child: AppSceneScrim.vertical()),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                topInset + AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.gapRow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionLabel('Métabolisme'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Ton moteur\naujourd’hui',
                    style: AppTypography.display
                        .copyWith(color: AppColors.darkTextPrimary),
                  ),
                  const Spacer(),
                  _ExpenditureRow(tdee: tdee, bmr: bmr, activity: activity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// « 2 759 » — séparateur de milliers commun à toute l'app.
  static String _kcal(int? value) =>
      value == null ? _placeholder : formatThousands(value);
}

/// Bas du hero : dépense totale à gauche, décomposition MB / activité à droite.
class _ExpenditureRow extends StatelessWidget {
  const _ExpenditureRow({
    required this.tdee,
    required this.bmr,
    required this.activity,
  });

  final int? tdee;
  final int? bmr;
  final int? activity;

  @override
  Widget build(BuildContext context) {
    final total = MetabolismHero._kcal(tdee);

    return Semantics(
      label: tdee == null
          ? 'Dépense totale indisponible : profil incomplet'
          : 'Dépense totale $total kilocalories, dont '
              '${MetabolismHero._kcal(bmr)} de métabolisme de base et '
              '${MetabolismHero._kcal(activity)} d’activité',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total,
                  style:
                      AppTypography.metricXL.copyWith(color: AppColors.accent),
                ),
                const SizedBox(height: AppSpacing.xs),
                const AppSectionLabel('Kcal / dépense totale'),
              ],
            ),
          ),
          if (bmr != null && activity != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppSectionLabel(
                  'MB ${MetabolismHero._kcal(bmr)}',
                  color: AppColors.darkTextTertiary,
                ),
                const SizedBox(height: AppSpacing.xxs),
                AppSectionLabel(
                  'Activité ${MetabolismHero._kcal(activity)}',
                  color: AppColors.darkTextTertiary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
