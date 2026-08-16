import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';
import '../../domain/reward.dart';
import '../controllers/reward_controllers.dart';
import 'axes_card.dart';
import 'first_award_card.dart';
import 'progression_header.dart';
import 'title_card.dart';

/// L'ATELIER LE JOUR OÙ IL OUVRE.
///
/// Trois blocs au lieu de cinq. Un compte neuf n'a rien à montrer, il a une
/// porte à ouvrir : l'écran doit donc être PLUS COURT que celui d'un compte
/// avancé, pas plus bavard. Une vitrine vide, une section « ce qui vient » et
/// un manifeste ne feraient qu'énumérer ce qui manque.
///
/// Aucun zéro nulle part : le total s'écrit « — », les jauges sont en tirets,
/// et chaque axe en attente dit comment s'ouvrir.
class FirstStepsBody extends ConsumerWidget {
  const FirstStepsBody({
    required this.profile,
    required this.initial,
    super.key,
  });

  final ProgressionProfile profile;
  final String initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = _firstReward(ref.watch(nextRewardsProvider));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProgressionHeader(
          subtitle: 'Ton atelier vient d’ouvrir.',
          initial: initial,
          // Le dégradé se gagne, comme le reste de l'écran.
          majestic: false,
        ),
        const SizedBox(height: AppSpacing.gapSection),
        TitleCard(profile: profile, majestyTier: CarlysTitle.apprenti),
        if (first != null) ...[
          const SizedBox(height: AppSpacing.gapSection),
          const AppSectionLabel('Ta première récompense'),
          const SizedBox(height: AppSpacing.gapRow),
          FirstAwardCard(
            reward: first,
            onStart: () => context.push(AppRoutes.academy),
          ),
        ],
        const SizedBox(height: AppSpacing.gapSection),
        const AppSectionLabel('Les cinq axes · tous en attente'),
        const SizedBox(height: AppSpacing.gapRow),
        AxesCard(axes: profile.axes),
      ],
    );
  }

  /// La récompense montrée est celle que le BOUTON permet d'atteindre : il
  /// ouvre une leçon, donc c'est un palier de Maîtrise qu'on affiche. Montrer
  /// une médaille de constance au-dessus d'un bouton « ouvrir une leçon »
  /// promettrait une chose et en donnerait une autre.
  static Reward? _firstReward(List<Reward> upcoming) {
    for (final reward in upcoming) {
      if (reward.value == CarlysValue.maitrise) return reward;
    }
    return upcoming.isEmpty ? null : upcoming.first;
  }
}
