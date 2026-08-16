import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';
import '../controllers/reward_controllers.dart';
import 'axes_card.dart';
import 'manifesto_tile.dart';
import 'progression_header.dart';
import 'reward_showcase.dart';
import 'title_card.dart';
import 'title_crossing_banner.dart';

/// L'ATELIER D'UN COMPTE QUI A DÉJÀ TRAVAILLÉ.
///
/// Cinq blocs, dans cet ordre : ce que tu portes, ce que tu as gagné, ce qui
/// vient, ce que tu vaux sur les cinq axes, et pourquoi ces axes-là. L'écran
/// finit sur la question plutôt que sur un score : c'est le manifeste qui
/// ferme, pas un total.
class ProgressionBody extends ConsumerWidget {
  const ProgressionBody({
    required this.profile,
    required this.initial,
    super.key,
  });

  final ProgressionProfile profile;

  /// L'initiale portée par l'avatar.
  final String initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProgressionHeader(
          subtitle: 'Ce que ton travail a déposé.',
          initial: initial,
        ),
        const SizedBox(height: AppSpacing.gapSection),
        const TitleCrossingBanner(),
        TitleCard(
          profile: profile,
          // La majesté suit le titre le plus haut JAMAIS atteint : une
          // interruption fait redescendre les points, jamais l'écrin.
          majestyTier: ref.watch(highestTitleProvider),
        ),
        const SizedBox(height: AppSpacing.gapSection),
        const RewardShowcase(),
        const SizedBox(height: AppSpacing.gapSection),
        const AppSectionLabel('Les cinq axes'),
        const SizedBox(height: AppSpacing.gapRow),
        AxesCard(axes: profile.axes),
        const SizedBox(height: AppSpacing.gapSection),
        ManifestoTile(onOpen: () => context.push(AppRoutes.manifesto)),
      ],
    );
  }
}
