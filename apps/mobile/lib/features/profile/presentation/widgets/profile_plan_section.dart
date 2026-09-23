import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/connection_aware_error.dart';
import '../../../subscription/presentation/controllers/subscription_controllers.dart';
import 'profile_plan_card.dart';

/// L'ABONNEMENT, en tête des réglages.
///
/// Le profil le lisait au `valueOrNull` : un `null` y voulait dire « pas de
/// donnée » aussi bien que « pas encore » et « pas pu ». Hors réseau, la
/// bannière disparaissait donc en silence, et l'écran affirmait par omission
/// que l'utilisateur n'avait pas d'abonnement.
///
/// La section sépare l'ÉCHEC du reste : hors ligne, elle le dit et propose
/// de réessayer. L'attente, elle, ne montre rien : une bannière qui n'est
/// pas encore là n'affirme rien, tandis qu'un indicateur se rallumerait à
/// chaque ouverture (la source est `autoDispose`).
///
/// Les tuiles de poids, de taille et de séances qui l'accompagnaient ont
/// quitté le profil avec la refonte de septembre 2026 : les séances se
/// comptent désormais sous l'identité, depuis toujours ; le poids vit dans
/// Progrès et la taille dans le profil nutritionnel, où elles se modifient.
class ProfilePlanSection extends ConsumerWidget {
  const ProfilePlanSection({required this.onOpenPlan, super.key});

  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planStatusProvider);

    return switch (plan) {
      AsyncError(:final error) => ConnectionAwareError(
        error: error,
        title: 'Abonnement indisponible',
        message: 'L’état de ton abonnement n’a pas pu être chargé.',
        offlineMessage:
            'Ton abonnement vit sur le serveur. Il revient avec le réseau.',
        onRetry: () => ref.invalidate(planStatusProvider),
      ),
      AsyncData(:final value) => ProfilePlanCard(
        plan: value,
        onTap: onOpenPlan,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
