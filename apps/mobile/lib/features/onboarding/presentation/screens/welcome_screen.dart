import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/first_run_controller.dart';
import '../widgets/brand_manifesto.dart';
import '../widgets/brand_pillars.dart';
import '../widgets/brand_signature.dart';
import '../widgets/welcome_backdrop.dart';

/// **Première chose que voit un nouvel arrivant** : qui est Carlys.
///
/// Elle précède l'onboarding : on dit ce qu'on est avant de demander quoi que
/// ce soit. Un seul chemin en sort — le bouton — et il ne fait qu'avancer le
/// parcours ; aucune promesse n'y est faite qui ne soit tenue par la suite.
///
/// Traduction fidèle du design validé (`handoff/reference/Welcome.dc.html`) :
/// les valeurs viennent de là et ne s'améliorent pas au jugé.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  /// Part de la largeur laissée au texte. Au-delà, il passerait sur la
  /// personne — et c'est aussi ce qui borne le fondu de la photographie
  /// (`AthletePhotoFraming.fadeFrom`), qui doit s'éteindre avant lui.
  @visibleForTesting
  static const double textWidthFactor = 0.64;

  /// Écart minimal entre le bloc haut et le bloc bas.
  static const double _blockGap = AppSpacing.xl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          const Positioned.fill(child: WelcomeBackdrop()),
          SafeArea(
            // En haut, la page passe SOUS la barre d'état : c'est une page de
            // marque, elle occupe l'écran entier. En bas, l'encoche est
            // respectée — le bouton doit rester atteignable.
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                // Elle ne défile que si l'écran est trop court : sur un
                // téléphone ordinaire, tout tient d'un seul regard.
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: AppSpacing.md,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.md * 2,
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FractionallySizedBox(
                        widthFactor: textWidthFactor,
                        alignment: Alignment.centerLeft,
                        child: _HeroBlock(),
                      ),
                      SizedBox(height: _blockGap),
                      _ActionBlock(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc haut : signature, accroche, credo, motif.
class _HeroBlock extends StatelessWidget {
  const _HeroBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandSignature(),
        SizedBox(height: AppSpacing.lg),
        BrandClaim(),
        SizedBox(height: AppSpacing.md),
        BrandCreed(),
        SizedBox(height: _motifGap),
        BrandProgressMotif(),
      ],
    );
  }

  /// Le motif se pose à distance du texte : il ferme le bloc, il ne le
  /// prolonge pas.
  static const double _motifGap = 40;
}

/// Bloc bas : les quatre univers, puis l'unique sortie de la page.
class _ActionBlock extends ConsumerWidget {
  const _ActionBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandPillars(),
        const SizedBox(height: AppSpacing.md),
        AppBrandButton(
          label: 'Commencer mon parcours',
          onPressed: () =>
              ref.read(firstRunControllerProvider.notifier).completeWelcome(),
        ),
      ],
    );
  }
}
