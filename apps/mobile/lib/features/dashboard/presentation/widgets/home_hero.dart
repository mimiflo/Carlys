import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../../design_system/scenes/heart_scene.dart';
import '../../../progress/domain/entities/progress.dart';
import 'fitness_index_block.dart';
import 'home_fact_pills.dart';
import 'home_header.dart';

/// Zone haute de l'accueil : scène cœur ancrée haut-droite qui déborde du
/// cadre, dégradés de lisibilité, en-tête, indice de forme et faits du jour.
class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.displayName,
    required this.fitnessIndex,
    required this.week,
    required this.restSinceLastWorkout,
    super.key,
  });

  final String? displayName;
  final int? fitnessIndex;
  final ProgressOverviewEntity? week;
  final Duration? restSinceLastWorkout;

  /// Géométrie de la maquette : scène de 330 posée à 22 du haut, débordant
  /// de 126 à droite.
  static const double _sceneSize = 330;
  static const double _sceneTop = 22;
  static const double _sceneRight = -126;

  /// Fondu vertical de la scène (transparent → plein → transparent).
  static const List<double> _sceneFade = [0.0, 0.18, 0.56, 0.90];

  /// Respiration entre l'en-tête et l'indice de forme, qui donne à la zone
  /// haute ses 322 de la maquette.
  static const double _headroom = 84;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          top: _sceneTop,
          right: _sceneRight,
          child: AppSceneContainer(
            size: _sceneSize,
            opacity: 0.9,
            verticalFadeStops: _sceneFade,
            child: HeartScene(),
          ),
        ),
        // Lisibilité : la colonne de texte est à gauche, le fond s'éteint
        // ensuite vers le bas.
        const Positioned.fill(child: AppSceneScrim.lateral()),
        const Positioned.fill(child: AppSceneScrim.vertical()),
        Padding(
          padding: EdgeInsets.only(top: topInset + AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: HomeHeader(displayName: displayName),
              ),
              const SizedBox(height: _headroom),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: FitnessIndexBlock(score: fitnessIndex),
              ),
              const SizedBox(height: AppSpacing.sm),
              HomeFactPills(
                week: week,
                restSinceLastWorkout: restSinceLastWorkout,
              ),
              const SizedBox(height: AppSpacing.gapRow),
            ],
          ),
        ),
      ],
    );
  }
}
