import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
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
  static const List<double> _photoFade = [0.0, 0.42, 1.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          Positioned.fill(child: _Photo(widthFactor: _photoWidthFactor)),
          // Assombrissement vertical : le bas de la page porte les vignettes
          // et le bouton, qui ont besoin d'un fond calme.
          const Positioned.fill(child: AppSceneScrim.vertical()),
          SafeArea(
            // La page tient l'écran : signature en haut, appel à l'action en
            // pied. Elle défile seulement si l'écran est trop court — jamais
            // de bloc flottant au milieu du vide.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.lg * 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          BrandSignature(),
                          SizedBox(height: AppSpacing.xl),
                          _Claim(),
                          SizedBox(height: AppSpacing.lg),
                          _Creed(),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandPillars(),
                          const SizedBox(height: AppSpacing.lg),
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

/// La promesse, en deux lignes.
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
          const TextSpan(text: 'SCULPTE TON PARCOURS.\nSIGNE TON '),
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
    final base = AppTypography.body.copyWith(
      fontSize: 15,
      height: 1.9,
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
