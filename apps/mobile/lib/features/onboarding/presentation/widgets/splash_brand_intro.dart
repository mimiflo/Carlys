import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/splash_gate.dart';
import 'brand_signature.dart';

/// Entrée de marque de l'écran de démarrage : le sceau paraît, la signature
/// se pose, un fil de lumière se remplit le temps que l'application se
/// prépare.
///
/// Un SEUL contrôleur mène toute la scène, découpé en intervalles. Trois
/// animations indépendantes dériveraient les unes des autres et rien ne
/// garantirait qu'elles finissent ensemble ; ici la fin de la course EST le
/// signal de départ ([onFinished]), il n'y a donc aucune durée à tenir
/// synchronisée avec [splashHold].
class SplashBrandIntro extends StatefulWidget {
  const SplashBrandIntro({required this.onFinished, super.key});

  /// Appelé une fois la scène terminée.
  final VoidCallback onFinished;

  /// Le sceau paraît d'abord, seul.
  static const Interval markInterval = Interval(0, 0.42, curve: Curves.easeOut);

  /// La signature suit, à peine décalée : c'est le même geste, pas deux.
  static const Interval wordInterval =
      Interval(0.22, 0.62, curve: AppMotion.standard);

  /// Le fil de lumière court sur toute la scène, moins la dernière respiration
  /// — il doit être PLEIN avant que l'écran ne s'efface, sinon il donne
  /// l'impression d'un chargement interrompu.
  static const Interval threadInterval =
      Interval(0.12, 0.9, curve: Curves.easeInOut);

  @override
  State<SplashBrandIntro> createState() => _SplashBrandIntroState();
}

class _SplashBrandIntroState extends State<SplashBrandIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: splashHold,
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La réduction d'animations système n'est connue qu'ici : sans elle, la
    // scène jouerait quand même et retiendrait l'écran pour rien.
    _controller.duration = AppMotion.resolve(context, splashHold);
    if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 5),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final mark = SplashBrandIntro.markInterval
                .transform(_controller.value.clamp(0.0, 1.0));
            final word = SplashBrandIntro.wordInterval
                .transform(_controller.value.clamp(0.0, 1.0));
            return Opacity(
              opacity: mark,
              child: Transform.scale(
                // Le sceau vient très légèrement de l'arrière : assez pour
                // qu'il s'installe, pas assez pour qu'il « saute ».
                scale: 0.94 + 0.06 * mark,
                child: Opacity(
                  opacity: 0.35 + 0.65 * word,
                  child: child,
                ),
              ),
            );
          },
          child: const BrandSignature(centered: true),
        ),
        const Spacer(flex: 4),
        _LoadingThread(progress: _controller),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

/// Fil de lumière : une ligne fine qui se remplit du dégradé de marque.
///
/// Pas un indicateur circulaire : celui-ci tourne sans fin et dit « ça
/// travaille » ; un fil qui se remplit dit « ça arrive », ce qui est la
/// vérité ici, la durée étant connue.
class _LoadingThread extends StatelessWidget {
  const _LoadingThread({required this.progress});

  final Animation<double> progress;

  static const double _width = 132;
  static const double _height = 3;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement de Carlys',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_height),
          child: SizedBox(
            width: _width,
            height: _height,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.darkBorder),
              child: AnimatedBuilder(
                animation: progress,
                builder: (context, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: SplashBrandIntro.threadInterval
                        .transform(progress.value.clamp(0.0, 1.0)),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(gradient: AppColors.signature),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
