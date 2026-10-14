import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Fond de l'onboarding (maquette d'octobre 2026) : le fond sombre de
/// l'application et un halo violet doux derrière l'en-tête — rien de plus.
///
/// Il portait le cœur ambiant de la marque ; posé derrière les cartes de
/// réponse, il n'en dépassait qu'un morceau, caché à moitié, qui brouillait
/// la question. La question et ses cartes portent l'écran ; le fond se tait.
class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.05),
            radius: 0.9,
            colors: [AppColors.backdropGlowSoft, AppColors.backdropClear],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}
