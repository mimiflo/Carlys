import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../controllers/splash_gate.dart';
import '../widgets/splash_brand_intro.dart';

/// Écran de démarrage : la marque s'installe pendant que l'application se
/// prépare.
///
/// Deux choses s'y passent en parallèle, et c'est voulu : la restauration de
/// session part dès la première frame, et l'animation de marque se déroule
/// sur [splashHold]. Le routeur n'ouvre l'application que lorsque les DEUX
/// sont finies — l'attente est donc celle de la plus longue, jamais leur
/// somme.
///
/// L'animation ne boucle pas. Une boucle d'ambiance ferait de cet écran un
/// puits sans fond pour `pumpAndSettle`, qui attend que plus aucune frame ne
/// soit programmée : toute la suite de tests monte l'application par ici.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Halo de marque, haut-centre : la même lueur violette que la page
          // de bienvenue, pour que les deux écrans se suivent sans rupture.
          const Positioned.fill(
            child: AppSceneGlow(
              center: Alignment(0, -0.35),
              radius: 0.75,
              alpha: 0.22,
            ),
          ),
          // `Positioned.fill` et non un enfant libre : une pile donne des
          // contraintes LÂCHES à ses enfants non positionnés et les cale en
          // haut à gauche. La colonne se réduisait alors à la largeur du mot
          // « CARLYS » et toute la scène se retrouvait dans l'angle.
          Positioned.fill(
            child: SafeArea(
              child: SplashBrandIntro(
                onFinished: () => ref.read(splashGateProvider.notifier).open(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
