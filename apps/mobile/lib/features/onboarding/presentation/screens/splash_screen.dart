import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/first_run_step.dart';
import '../controllers/first_run_controller.dart';
import '../controllers/splash_gate.dart';
import '../widgets/athlete_photo.dart';
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
  bool _athletePrecached = false;

  @override
  void initState() {
    super.initState();
    // L'étape du parcours n'est connue qu'une fois la session restaurée :
    // on l'ÉCOUTE, et la photographie ne se précharge que si elle mène à la
    // page de bienvenue.
    ref.listenManual<FirstRunStep?>(firstRunStepProvider, (_, step) {
      if (step == FirstRunStep.welcome) _precacheAthlete();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).restore();
    });
  }

  /// Décode la photographie de la page de bienvenue PENDANT le plancher.
  ///
  /// La page qui suit s'ouvre sur un cliché de 1 024 × 1 536 : décodé au
  /// moment où la route se pousse, il apparaissait en retard, au milieu de
  /// la transition — l'à-coup se voyait à chaque première ouverture. Le
  /// plancher de cet écran offre 2,6 s de calme : le décodage s'y glisse et
  /// la transition trouve l'image déjà en cache. Le sceau de la signature,
  /// lui, n'a pas besoin de ce geste : cet écran-ci l'affiche déjà.
  ///
  /// SEULEMENT pour qui va la voir. Seule la page de bienvenue du premier
  /// parcours l'affiche ; l'habitué, parcours terminé, va droit à l'accueil.
  /// Précharger à chaque démarrage lui coûtait 6 Mio d'image décodée, gardés
  /// dans le cache, pour rien.
  void _precacheAthlete() {
    if (_athletePrecached || !mounted) return;
    _athletePrecached = true;
    unawaited(precacheImage(const AssetImage(AthletePhoto.asset), context));
  }

  @override
  Widget build(BuildContext context) {
    return AppDarkScaffold(
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
