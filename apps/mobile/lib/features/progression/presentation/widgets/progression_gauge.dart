import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// LA JAUGE, et sa règle : **jamais une piste vide**.
///
/// Une jauge à zéro se lit comme un échec alors qu'il n'y a simplement rien
/// encore. Sans remplissage, la piste passe donc en TIRETS : elle dit « pas
/// encore », pas « raté ».
///
/// Elle se remplit sous les yeux à l'affichage : une barre déjà pleine à
/// l'arrivée ne raconte pas le chemin parcouru.
class ProgressionGauge extends StatefulWidget {
  const ProgressionGauge({
    required this.value,
    required this.height,
    this.fill,
    this.animate = true,
    super.key,
  });

  /// Part remplie, de 0 à 1. Ignorée sans [fill].
  final double value;

  final double height;

  /// `null` : la piste est en tirets, le compteur n'est pas ouvert.
  final Gradient? fill;

  final bool animate;

  /// Le remplissage suit le token des anneaux et des jauges.
  static const Duration fillDuration = AppMotion.ring;

  /// Longueur d'un tiret, et de l'espace qui le suit.
  static const double dash = 5;

  @override
  State<ProgressionGauge> createState() => _ProgressionGaugeState();
}

class _ProgressionGaugeState extends State<ProgressionGauge> {
  double _shown = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.animate) {
      _shown = widget.value;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = widget.value);
    });
  }

  @override
  void didUpdateWidget(ProgressionGauge old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _shown = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.fill;
    if (fill == null) {
      return SizedBox(
        height: widget.height,
        child: CustomPaint(
          painter: const DashedTrack(),
          size: Size.infinite,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        height: widget.height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.gaugeTrack),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _shown),
            duration: AppMotion.resolve(
              context,
              ProgressionGauge.fillDuration,
            ),
            curve: AppMotion.standard,
            builder: (context, value, _) => Align(
              alignment: Alignment.centerLeft,
              // Jamais tout à fait zéro : une largeur nulle libère la
              // contrainte, et l'enfant se peindrait à sa taille naturelle.
              widthFactor: value.clamp(0.001, 1),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: fill),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La piste en tirets d'un compteur pas encore ouvert.
@visibleForTesting
class DashedTrack extends CustomPainter {
  const DashedTrack();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.pendingTrack;
    // Des TIRETS, pas des points : cinq points pleins, cinq vides, à bouts
    // DROITS. Arrondir les bouts d'un tiret aussi court que la piste est
    // épaisse le transformerait en pastille, et une piste pointillée ne dit
    // plus « en attente » — elle ressemble à une décoration.
    for (var x = 0.0; x < size.width; x += ProgressionGauge.dash * 2) {
      final width = (size.width - x).clamp(0.0, ProgressionGauge.dash);
      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(DashedTrack oldDelegate) => false;
}
