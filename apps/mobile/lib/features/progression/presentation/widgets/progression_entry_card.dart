import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/illustrated_banner.dart';
import '../../../../shared/widgets/summit_illustration.dart';

/// « Mon parcours » (maquette Progrès d'octobre 2026) : la porte du profil
/// de progression — titres, récompenses, axes et frise — depuis l'écran
/// Progrès, qui raconte la période quand le profil raconte l'histoire.
///
/// Elle ne lit AUCUNE donnée : elle s'affiche donc même quand les
/// statistiques du serveur, autour d'elle, sont hors ligne ou en erreur.
class ProgressionEntryCard extends StatelessWidget {
  const ProgressionEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return IllustratedBanner(
      title: 'Mon parcours',
      body: 'Titres et récompenses',
      leading: const AppMedal(metal: AppMedalMetal.bronze),
      // La médaille prend sa place au texte : le sommet la lui rend.
      summitShift: SummitIllustration.wideTextShift,
      onTap: () => context.push(AppRoutes.progression),
    );
  }
}
