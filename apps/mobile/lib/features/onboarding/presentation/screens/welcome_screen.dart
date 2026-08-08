import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/first_run_controller.dart';
import '../widgets/brand_pillars.dart';
import '../widgets/brand_signature.dart';

/// **Première chose que voit un nouvel arrivant** : qui est Carlys.
///
/// Elle précède l'onboarding : on dit ce qu'on est avant de demander quoi que
/// ce soit. Un seul chemin en sort — le bouton — et il ne fait qu'avancer le
/// parcours ; aucune promesse n'y est faite qui ne soit tenue par la suite.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  /// Photographie de marque, à droite, fondue dans le fond.
  static const String athleteAsset = 'assets/brand/carlys-athlete.jpg';

  /// Part de la largeur occupée par la photographie.
  static const double _photoWidthFactor = 0.62;

  /// Fondu de la photographie vers le fond : opaque à droite, transparente
  /// avant la colonne de texte. Sans lui, le cliché formerait un rectangle
  /// posé sur la page.
  ///
  /// Le fondu est COURT — il ne mange que le bord gauche du cliché. Étalé, il
  /// délavait la personne sur la moitié de sa largeur : on ne montre pas
  /// quelqu'un pour l'effacer ensuite. Assez long, tout de même, pour qu'aucune
  /// couture verticale ne se lise entre la page et le cliché.
  static const List<double> _photoFade = [0.0, 0.30, 1.0];

  /// Part de la largeur laissée au texte. Il ne déborde pas dessus.
  static const double _textWidthFactor = 0.64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          Positioned.fill(child: _Photo(widthFactor: _photoWidthFactor)),
          const Positioned.fill(child: _Veil()),
          SafeArea(
            // La page tient l'écran : signature en haut, appel à l'action en
            // pied. Elle défile seulement si l'écran est trop court — jamais
            // de bloc flottant au milieu du vide.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: AppSpacing.md,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.md * 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Le texte reste dans SA colonne. Étalé sur toute la
                      // largeur, il se posait sur la personne : ni le texte ni
                      // la photographie n'y gagnaient.
                      FractionallySizedBox(
                        widthFactor: _textWidthFactor,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            BrandSignature(),
                            SizedBox(height: AppSpacing.lg),
                            _Claim(),
                            SizedBox(height: AppSpacing.md),
                            _Creed(),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandPillars(),
                          const SizedBox(height: AppSpacing.md),
                          AppBrandButton(
                            label: 'Commencer mon parcours',
                            onPressed: () => ref
                                .read(firstRunControllerProvider.notifier)
                                .completeWelcome(),
                          ),
                        ],
                      ),
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

/// Deux voiles LÉGERS, chacun pour une raison précise.
///
/// L'assombrissement générique des scènes 3D ([AppSceneScrim]) couvre toute la
/// hauteur et éteignait la personne. Ici on n'assombrit que ce qui doit l'être :
/// la colonne de gauche, où vit le texte, et le tout bas, où se posent les
/// vignettes et le bouton. Entre les deux, le cliché reste net.
class _Veil extends StatelessWidget {
  const _Veil();

  /// Colonne de lecture : opaque au bord gauche — c'est déjà le fond — et
  /// éteinte avant le milieu.
  static const List<double> _readingStops = [0.0, 0.28, 0.58];

  /// Pied de page : rien ne s'assombrit avant les deux tiers.
  static const List<double> _footStops = [0.62, 0.86, 1.0];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.darkBackground,
                    Color(0x7306060C),
                    Colors.transparent,
                  ],
                  stops: _readingStops,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x9906060C),
                    AppColors.darkBackground,
                  ],
                  stops: _footStops,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La photographie, ancrée à droite et fondue vers la gauche.
class _Photo extends StatelessWidget {
  const _Photo({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        // Toute la hauteur : sans cela l'image s'arrête à sa proportion
        // naturelle et laisse une bande noire sous elle.
        heightFactor: 1,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.transparent, Colors.white, Colors.white],
            stops: WelcomeScreen._photoFade,
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: Image.asset(
            WelcomeScreen.athleteAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.medium,
            // Décoratif : la lecture d'écran n'a rien à en dire.
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// La promesse, en quatre lignes courtes.
///
/// Les coupes sont ÉCRITES, pas laissées au retour à la ligne automatique :
/// c'est une accroche d'affiche, son rythme fait partie du message.
class _Claim extends StatelessWidget {
  const _Claim();

  static const double _size = 24;

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.title.copyWith(
      fontSize: _size,
      height: 1.24,
      fontWeight: FontWeight.w700,
      color: AppColors.neutral0,
    );

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'SCULPTE\nTON PARCOURS.\nSIGNE TON\n'),
          TextSpan(
            text: 'CHEF-D’ŒUVRE.',
            style: base.copyWith(color: AppColors.signatureMid),
          ),
        ],
      ),
      style: base,
    );
  }
}

/// Les trois affirmations qui disent à qui appartient le parcours.
class _Creed extends StatelessWidget {
  const _Creed();

  static const List<(String, String, String)> _lines = [
    ('Ton corps est ', 'TON', ' œuvre.'),
    ('Ton parcours est ', 'TON', ' histoire.'),
    ('Ta discipline est ', 'TA', ' signature.'),
  ];

  @override
  Widget build(BuildContext context) {
    // 14 et non 15 : à 15, « Ton parcours est TON histoire. » débordait de la
    // colonne et laissait « histoire. » seul sur sa ligne.
    final base = AppTypography.body.copyWith(
      fontSize: 14,
      height: 1.75,
      color: AppColors.darkTextSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (before, accent, after) in _lines)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: before),
                TextSpan(
                  text: accent,
                  style: base.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral0,
                  ),
                ),
                TextSpan(text: after),
              ],
            ),
            style: base,
          ),
      ],
    );
  }
}
