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

  /// Descendu par rapport à la maquette : sur un téléphone réel, le cœur
  /// mordait sur l'avatar du profil, en haut à droite.
  static const double _sceneTop = 64;
  static const double _sceneRight = -126;

  /// Fondu vertical de la scène (transparent → plein → transparent).
  /// Le fondu doit être ACHEVÉ avant le bas de la zone haute, sinon la scène
  /// se fait trancher net à la limite du bloc.
  static const List<double> _sceneFade = [0.0, 0.16, 0.46, 0.76];

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
        // Lisibilité, dans l'ordre de la maquette (la couche listée en premier
        // en CSS est la plus haute) : extinction verticale, puis assombrissement
        // latéral, puis le halo violet PAR-DESSUS.
        const Positioned.fill(child: AppSceneScrim.vertical()),
        const Positioned.fill(child: AppSceneScrim.lateral()),
        const Positioned.fill(
          child: AppSceneGlow(
            center: Alignment(0.48, -0.16),
            radius: 0.71,
            alpha: 0.32,
          ),
        ),
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
