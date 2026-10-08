import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/illustrated_banner.dart';
import '../../../../shared/widgets/summit_illustration.dart';
import '../providers/reward_providers.dart';

/// « Mon parcours » (maquette Progrès d'octobre 2026) : la porte du profil
/// de progression — titres, récompenses, axes et frise — depuis l'écran
/// Progrès, qui raconte la période quand le profil raconte l'histoire.
///
/// La médaille dit ce qui est VRAI : en bronze dès la première récompense,
/// sous cadenas avant. Une médaille pleine sur un compte neuf se lisait
/// comme une récompense déjà obtenue. Elle se fonde sur la vitrine, tirée
/// des faits locaux : la porte s'affiche même quand les statistiques du
/// serveur, autour d'elle, sont hors ligne ou en erreur.
class ProgressionEntryCard extends ConsumerWidget {
  const ProgressionEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = ref.watch(showcaseRewardsProvider).isNotEmpty;
    return IllustratedBanner(
      title: 'Mon parcours',
      body: 'Titres et récompenses',
      leading: AppMedal(metal: earned ? AppMedalMetal.bronze : null),
      // La médaille prend sa place au texte : le sommet la lui rend.
      summitShift: SummitIllustration.wideTextShift,
      onTap: () => context.push(AppRoutes.progression),
    );
  }
}
