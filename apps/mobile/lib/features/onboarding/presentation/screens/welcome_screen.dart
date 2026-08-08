import 'dart:math' as math;

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

  /// Largeur de l'écran sur lequel le design a été validé, en points.
  ///
  /// Déduite de la planche : le bouton, haut de 58 points, y mesure 158 pixels,
  /// soit un facteur 2,72 pour une image de 1186 de large. Toutes les tailles
  /// de la spécification sont donc pensées POUR cette largeur — sur un
  /// téléphone plus étroit, les mêmes points occupent une part plus grande, et
  /// le texte finissait par toucher la personne (et par se casser en deux
  /// lignes sur les petits écrans).
  static const double designWidth = 435;

  /// Échelle du bloc de texte pour tenir les mêmes PROPORTIONS que la planche.
  ///
  /// Jamais au-dessus de 1 : sur un écran plus large, on ne grossit pas le
  /// texte, on lui laisse de l'air.
  @visibleForTesting
  static double scaleFor(Size screen) =>
      math.min(1, screen.width / designWidth);

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
                    minHeight:
                        constraints.maxHeight - AppSpacing.md - AppSpacing.xxl,
                  ),
                  // La hauteur devient DÉFINIE, ce qui autorise les respirations
                  // proportionnelles ci-dessous. Sans ça, la colonne n'a qu'un
                  // minimum et `Spacer` n'a rien à répartir.
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Le vide se partage moitié-moitié entre le haut de la
                        // page et l'entre-deux. Tout lui donner au milieu —
                        // `spaceBetween` — collait le texte en haut : la planche
                        // n'a presque pas de vide à répartir, un téléphone en a
                        // beaucoup, et le bloc y restait échoué contre le bord.
                        // Un quart du vide au-dessus, trois quarts entre les
                        // blocs. La planche n'a presque pas de vide à
                        // répartir ; un téléphone en a beaucoup, et tout lui
                        // donner au milieu laissait le texte échoué contre le
                        // bord haut. Un `Spacer` se rétracte à zéro quand
                        // l'écran est juste — le pied de page reste
                        // atteignable.
                        const Spacer(),
                        FractionallySizedBox(
                          widthFactor: textWidthFactor,
                          alignment: Alignment.centerLeft,
                          child: _HeroBlock(
                            scale: scaleFor(constraints.biggest),
                          ),
                        ),
                        const Spacer(flex: 2),
                        const SizedBox(height: _blockGap),
                        const _ActionBlock(),
                        // Le pied de page ne colle plus au bord : il remonte
                        // vers le centre. La planche n'a presque pas de vide à
                        // répartir, un téléphone en a beaucoup — collé en bas,
                        // le bloc s'y retrouvait isolé, très loin du texte.
                        const Spacer(flex: 2),
                      ],
                    ),
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
  const _HeroBlock({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandSignature(scale: scale),
        SizedBox(height: AppSpacing.lg * scale),
        BrandClaim(scale: scale),
        SizedBox(height: AppSpacing.md * scale),
        BrandCreed(scale: scale),
        SizedBox(height: _motifGap * scale),
        BrandProgressMotif(scale: scale),
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
