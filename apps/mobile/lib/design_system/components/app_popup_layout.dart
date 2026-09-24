import 'package:flutter/widgets.dart';

import '../motion/app_motion.dart';
import '../spacing/app_spacing.dart';
import 'app_popup_card.dart';

/// OÙ se pose une popup : au milieu de l'écran, jamais sous la barre d'état
/// ni sous le clavier, et défilable quand le texte agrandi la rend plus
/// haute que l'écran.
///
/// Partagé par les deux mécaniques d'affichage : la route des popups
/// (`showAppDialog`) et l'overlay des messages passagers (`AppNotices`).
/// Interne au design system : un écran appelle l'une de ces portes, jamais
/// ce gabarit.
class AppPopupLayout extends StatelessWidget {
  const AppPopupLayout({required this.child, super.key});

  /// La carte ([AppPopupCard]) à centrer.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Le clavier ouvert réduit l'écran utile : la carte se centre dans ce
      // qui reste, et son champ reste visible pendant qu'on écrit.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Un toucher à côté de la carte doit atteindre le voile, qui
            // ferme : le défilement ne répond donc qu'à la carte elle-même.
            hitTestBehavior: HitTestBehavior.deferToChild,
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppPopupCard.maxWidth,
              ),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'apparition d'une popup : un fondu et un léger zoom, de
/// [enterScale] à 1, sur les durées et courbes d'[AppMotion].
///
/// Quand le système demande de réduire les animations, rien ne bouge : la
/// popup est là, entière, dès la première image.
class AppPopupTransition extends StatefulWidget {
  const AppPopupTransition({
    required this.animation,
    required this.child,
    super.key,
  });

  /// De 0 (absente) à 1 (posée).
  final Animation<double> animation;
  final Widget child;

  /// Échelle de départ : assez proche de 1 pour que la carte semble se
  /// poser, pas surgir.
  static const double enterScale = 0.94;

  @override
  State<AppPopupTransition> createState() => _AppPopupTransitionState();
}

class _AppPopupTransitionState extends State<AppPopupTransition> {
  late CurvedAnimation _curve = _curveOf(widget.animation);
  late Animation<double> _scale = _scaleOf(_curve);

  static CurvedAnimation _curveOf(Animation<double> parent) => CurvedAnimation(
    parent: parent,
    curve: AppMotion.standard,
    reverseCurve: AppMotion.accelerate,
  );

  static Animation<double> _scaleOf(Animation<double> curve) => Tween<double>(
    begin: AppPopupTransition.enterScale,
    end: 1,
  ).animate(curve);

  @override
  void didUpdateWidget(AppPopupTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _curve.dispose();
      _curve = _curveOf(widget.animation);
      _scale = _scaleOf(_curve);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _curve,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
