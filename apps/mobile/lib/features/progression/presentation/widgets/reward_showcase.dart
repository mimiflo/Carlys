import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';
import '../controllers/reward_controllers.dart';
import 'award_cards.dart';

/// LA VITRINE, EN TROIS DENSITÉS.
///
/// La plus récente passe en VEDETTE, les deux suivantes en LIGNES, le reste
/// se compte dans l'en-tête. Neuf lignes identiques devenaient un mur :
/// personne ne lisait après la troisième, et la neuvième médaille dévaluait
/// la première.
///
/// Elle montre aussi CE QUI VIENT, et jamais l'une sans l'autre : une vitrine
/// qui n'afficherait que l'obtenu ne donnerait aucune direction ; une qui
/// n'afficherait que le manquant serait un compte de ce qu'on n'a pas.
class RewardShowcase extends ConsumerWidget {
  const RewardShowcase({this.showUpcoming = true, super.key});

  /// La section « Ce qui vient ». Repliée là où la vitrine n'est qu'un
  /// aperçu — l'écran Progrès a déjà sa propre direction.
  final bool showUpcoming;

  /// Vedette comprise. Au-delà, c'est le report qui prend le relais.
  static const int shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = ref.watch(showcaseRewardsProvider);
    if (earned.isEmpty) return const SizedBox.shrink();

    final featured = earned.first;
    final rows = earned.skip(1).take(shown - 1);
    final next = ref.watch(nextRewardsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Récompenses · ${earned.length}',
          trailing: earned.length > shown ? 'Voir les ${earned.length}' : null,
          trailingTone: AppSectionTrailingTone.primary,
          onTrailingTap: earned.length > shown
              ? () => showAllAwardsSheet(context, earned)
              : null,
        ),
        const SizedBox(height: AppSpacing.gapRow),
        FeaturedAwardCard(entry: featured),
        for (final entry in rows) ...[
          const SizedBox(height: AppSpacing.gapRow),
          AwardRow(entry: entry),
        ],
        if (showUpcoming && next.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gapSection),
          const AppSectionLabel('Ce qui vient'),
          const SizedBox(height: AppSpacing.gapRow),
          for (final (index, reward) in next.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            UpcomingAwardRow(reward: reward),
          ],
        ],
      ],
    );
  }
}

/// Toutes les récompenses, ouvertes depuis « Voir les N ».
///
/// Une feuille plutôt qu'un écran : on y jette un œil et on revient. Ouvrir
/// une page entière pour une liste qu'on parcourt en trois secondes coûterait
/// une navigation pour rien.
Future<void> showAllAwardsSheet(
  BuildContext context,
  List<EarnedReward> awards,
) {
  return showAppSheet<void>(
    context,
    style: AppSheetStyle.picker,
    builder: (_) => _AllAwardsSheet(awards: awards),
  );
}

class _AllAwardsSheet extends StatelessWidget {
  const _AllAwardsSheet({required this.awards});

  final List<EarnedReward> awards;

  @override
  Widget build(BuildContext context) {
    // Les marges système (haut ET bas) sont déjà prises par `showAppSheet`.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(title: 'Tes ${awards.length} récompenses'),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: awards.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, index) => AwardRow(entry: awards[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
