import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../domain/entities/nutrition.dart';
import 'dna_helix.dart';

/// Hero « métabolisme » (maquette 2g) : hélice ADN plein cadre décalée à
/// droite, halo violet, dégradés de lisibilité pour la colonne de gauche.
///
/// Il a DEUX états, et c'est la seule décision qu'il prend. Avec un
/// métabolisme, la dépense totale en très grand. Sans, une phrase et la porte
/// vers le formulaire : un tiret géant en accent servait l'absence comme si
/// c'était le fait principal, sans jamais dire comment en sortir — la
/// maladie que l'accueil vient de soigner avec son amorçage.
class MetabolismHero extends StatelessWidget {
  const MetabolismHero({
    required this.metabolism,
    required this.onCompleteProfile,
    super.key,
  });

  final MetabolismResult? metabolism;

  /// Mène au formulaire de profil ; ne sert que sans métabolisme.
  final VoidCallback onCompleteProfile;

  /// Géométrie relevée sur la maquette : hero de 378, scène centrée en
  /// largeur (c'est `root.position.x = 0.9` qui décale l'hélice vers la
  /// droite, pas le cadrage) et remontée de 35 pour passer sous la barre
  /// d'état. La hauteur de canevas 361 donne l'échelle de la référence :
  /// 26 barreaux espacés de 55,3 points à l'écran.
  static const double _heroHeight = 378;
  static const double _sceneTop = -35;
  static const double _helixHeight = 361;

  /// Fondu vertical de la scène (transparent → plein → transparent).
  static const List<double> _sceneFade = [0.0, 0.16, 0.62, 0.94];

  /// Halo violet de la maquette (.22) obtenu depuis le halo du design system.
  static const double _haloOpacity = 0.85;

  @override
  Widget build(BuildContext context) {
    final result = metabolism;
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
            // Jamais au-dessus du bord : la scène serait tranchée net,
            // fondu compris, sur les écrans sans encoche.
            top: math.max(0, topInset + _sceneTop),
            left: 0,
            right: 0,
            child: const Center(
              child: AppSceneContainer(
                size: _heroHeight,
                opacity: 1,
                verticalFadeStops: _sceneFade,
                child: Center(child: DnaHelix(height: _helixHeight)),
              ),
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
                  if (result != null)
                    _ExpenditureRow(metabolism: result)
                  else
                    _ProfilePrompt(onCompleteProfile: onCompleteProfile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bas du hero : dépense totale à gauche, décomposition MB / activité à droite.
class _ExpenditureRow extends StatelessWidget {
  const _ExpenditureRow({required this.metabolism});

  final MetabolismResult metabolism;

  @override
  Widget build(BuildContext context) {
    // « 2 759 » — séparateur de milliers commun à toute l'app.
    final total = formatThousands(metabolism.tdeeKcal);
    final bmr = formatThousands(metabolism.bmrKcal);
    // Activité = dépense totale − métabolisme de base : aucune valeur inventée.
    final activity = formatThousands(metabolism.tdeeKcal - metabolism.bmrKcal);

    return Semantics(
      label: 'Dépense totale $total kilocalories, dont $bmr de métabolisme '
          'de base et $activity d’activité',
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppSectionLabel('MB $bmr', color: AppColors.darkTextTertiary),
              const SizedBox(height: AppSpacing.xxs),
              AppSectionLabel(
                'Activité $activity',
                color: AppColors.darkTextTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bas du hero SANS métabolisme : ce qui manque, dit une fois, et la porte.
///
/// Le hero garde son hélice et son titre — il ne prétend plus donner un
/// chiffre. Le bouton mène au formulaire, qui est le seul geste utile du
/// premier jour.
class _ProfilePrompt extends StatelessWidget {
  const _ProfilePrompt({required this.onCompleteProfile});

  final VoidCallback onCompleteProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Carlys ne connaît pas encore ton moteur. Ta dépense du jour '
          'apparaîtra ici dès que ton profil sera complet.',
          style:
              AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Compléter mon profil',
          icon: AppIcons.arrowForward,
          onPressed: onCompleteProfile,
        ),
      ],
    );
  }
}
