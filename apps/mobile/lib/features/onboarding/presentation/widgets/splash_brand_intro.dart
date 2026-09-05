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
  static const Interval wordInterval = Interval(
    0.22,
    0.62,
    curve: AppMotion.standard,
  );

  /// Le fil de lumière court sur toute la scène, moins la dernière respiration
  /// — il doit être PLEIN avant que l'écran ne s'efface, sinon il donne
  /// l'impression d'un chargement interrompu.
  static const Interval threadInterval = Interval(
    0.12,
    0.9,
    curve: Curves.easeInOut,
  );

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
            final mark = SplashBrandIntro.markInterval.transform(
              _controller.value.clamp(0.0, 1.0),
            );
            final word = SplashBrandIntro.wordInterval.transform(
              _controller.value.clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: mark,
              child: Transform.scale(
                // Le sceau vient très légèrement de l'arrière : assez pour
                // qu'il s'installe, pas assez pour qu'il « saute ».
                scale: 0.94 + 0.06 * mark,
                child: Opacity(opacity: 0.35 + 0.65 * word, child: child),
              ),
            );
          },
          child: const BrandSignature(centered: true),
        ),
        // Le filet se pose SOUS la devise, à portée de regard : rejeté en
        // bas d'écran, il vivait sa vie de son côté et la marque restait
        // seule au milieu.
        const SizedBox(height: AppSpacing.xl),
        _LoadingThread(progress: _controller),
        const Spacer(flex: 6),
      ],
    );
  }
}

/// Fil de lumière : un filet que le dégradé de marque parcourt, sa lueur
/// avec lui.
///
/// Pas un indicateur circulaire : celui-ci tourne sans fin et dit « ça
/// travaille » ; un fil qui se remplit dit « ça arrive », ce qui est la
/// vérité ici, la durée étant connue.
///
/// Pas de pastille en tête non plus : elle donnait un curseur de réglage,
/// gros et matériel, au milieu d'une page qui ne vit que de lumière. Ce qui
/// avance est une lueur, pas une pièce.
///
/// Le dégradé est peint sur TOUTE la longueur puis dévoilé, au lieu d'être
/// étiré à la largeur remplie : les couleurs restent à leur place et c'est la
/// lumière qui avance, pas la palette qui se comprime.
class _LoadingThread extends StatelessWidget {
  const _LoadingThread({required this.progress});

  final Animation<double> progress;

  static const double _width = 116;
  static const double _rail = 2;

  /// La boîte respire au-delà du filet : la lueur a besoin de place, sinon
  /// elle serait coupée net en haut et en bas.
  static const double _box = 16;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement de Carlys',
      child: ExcludeSemantics(
        child: SizedBox(
          width: _width,
          height: _box,
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              final filled = SplashBrandIntro.threadInterval.transform(
                progress.value.clamp(0.0, 1.0),
              );
              return Stack(
                alignment: Alignment.center,
                children: [
                  const _Rail(),
                  _Glow(filled: filled),
                  _Fill(filled: filled),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Le filet vide : à peine là, mais présent — sans lui, la barre n'aurait
/// pas de longueur annoncée et l'attente paraîtrait sans fin.
class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _LoadingThread._rail,
      decoration: BoxDecoration(
        color: AppColors.darkBorderStrong,
        borderRadius: BorderRadius.circular(_LoadingThread._rail),
      ),
    );
  }
}

/// La lueur sous la part parcourue.
///
/// Posée AVANT le dégradé et hors du découpage : une ombre portée peinte à
/// l'intérieur du clip serait rognée avec lui, et ne déborderait donc jamais
/// — or c'est tout ce qu'on lui demande.
class _Glow extends StatelessWidget {
  const _Glow({required this.filled});

  final double filled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: (_LoadingThread._width * filled).clamp(1.0, double.infinity),
        height: _LoadingThread._rail,
        child: DecoratedBox(
          // Aucune couleur de fond : seules les ombres se peignent, et le
          // dégradé passera par-dessus.
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryFlash.withValues(alpha: 0.40),
                blurRadius: 10,
              ),
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.20),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La part parcourue, découpée dans un dégradé peint sur toute la longueur.
class _Fill extends StatelessWidget {
  const _Fill({required this.filled});

  final double filled;

  @override
  Widget build(BuildContext context) {
    // L'`Align` EXTÉRIEUR est indispensable : le découpage ne fait que la
    // largeur parcourue, et la pile, qui centre ses enfants, le poserait au
    // milieu du filet. La barre se remplissait alors depuis son centre.
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_LoadingThread._rail),
        child: Align(
          alignment: Alignment.centerLeft,
          // Cet `Align`-ci se dimensionne à une FRACTION de son enfant, et
          // c'est ce découpage qui dévoile le dégradé. Jamais tout à fait
          // zéro : une largeur nulle escamoterait la boîte.
          widthFactor: filled.clamp(0.001, 1),
          child: Container(
            width: _LoadingThread._width,
            height: _LoadingThread._rail,
            decoration: const BoxDecoration(gradient: AppColors.signature),
          ),
        ),
      ),
    );
  }
}
