import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../subscription/presentation/controllers/subscription_controllers.dart';
import '../controllers/profile_controllers.dart';
import 'profile_plan_card.dart';
import 'profile_stat_tiles.dart';

/// LE BLOC SERVEUR DU PROFIL : l'abonnement et les trois chiffres.
///
/// Quatre sources distinctes le nourrissent, toutes servies par l'API. Le
/// profil les lisait au `valueOrNull` : un `null` y voulait dire « pas de
/// donnée » aussi bien que « pas encore » et « pas pu ». Hors réseau, la
/// bannière d'abonnement et les tuiles disparaissaient donc en silence, et
/// l'écran affirmait par omission que l'utilisateur n'avait ni abonnement,
/// ni poids, ni taille, ni séance.
///
/// Le bloc sépare maintenant l'ÉCHEC du reste : hors ligne, il le dit et
/// propose de réessayer, au lieu de laisser un écran muet affirmer par
/// omission. Les réglages qui suivent, eux, tiennent sur des faits LOCAUX :
/// ils restent affichés quoi qu'il arrive au réseau, comme le profil de
/// progression sur l'écran Progrès.
///
/// L'attente, elle, ne montre rien : une carte ou une tuile qui n'est pas
/// encore là n'affirme rien, tandis qu'un indicateur en haut du profil se
/// rallumerait à chaque ouverture (les quatre sources sont `autoDispose`).
/// Chaque bloc apparaît donc quand sa source a répondu, et pas avant.
class ProfileSummary extends ConsumerWidget {
  const ProfileSummary({required this.onOpenPlan, super.key});

  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planStatusProvider);
    final report = ref.watch(metabolismReportProvider);
    final sessions = ref.watch(profileSessionsOverviewProvider);
    final weights = ref.watch(bodyWeightMetricsProvider);

    // La PREMIÈRE erreur porte la cause : hors ligne ou panne, l'état
    // affiché le dit — c'est la façon de faire de l'écran Communauté.
    final error = plan.error ?? report.error ?? sessions.error ?? weights.error;
    if (error != null) {
      return ConnectionAwareError(
        error: error,
        title: 'Profil indisponible',
        message: 'Ton abonnement et tes chiffres n’ont pas pu être chargés.',
        offlineMessage:
            'Ton abonnement et tes chiffres vivent sur le serveur. '
            'Ils reviennent avec le réseau.',
        onRetry: () {
          ref
            ..invalidate(planStatusProvider)
            ..invalidate(metabolismReportProvider)
            ..invalidate(profileSessionsOverviewProvider)
            ..invalidate(bodyWeightMetricsProvider);
        },
      );
    }

    final planStatus = plan.valueOrNull;
    final measures = weights.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (planStatus != null) ...[
          ProfilePlanCard(plan: planStatus, onTap: onOpenPlan),
          const SizedBox(height: AppSpacing.md),
        ],
        ProfileStatTiles(
          weightKg: measures == null || measures.isEmpty
              ? null
              : measures.last.value,
          heightCm: report.valueOrNull?.profile.heightCm,
          sessionsCount: sessions.valueOrNull?.sessionsCount,
        ),
      ],
    );
  }
}
