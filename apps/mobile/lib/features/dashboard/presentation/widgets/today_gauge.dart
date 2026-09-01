import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// La jauge d'une cellule d'AUJOURD'HUI : un filet de deux points sous le
/// chiffre.
///
/// Sans cible connue, elle passe en tirets. Une piste vide se lirait comme un
/// échec là où il n'y a simplement pas d'objectif — la distinction entre
/// « rien fait » et « rien à viser » se joue ici, pas dans le texte.
class TodayGauge extends StatelessWidget {
  const TodayGauge({required this.ratio, required this.tint, super.key});

  /// Part remplie, de 0 à 1. `null` : la piste passe en tirets.
  final double? ratio;

  final Color tint;

  static const double height = 2;

  @override
  Widget build(BuildContext context) {
    final value = ratio;
    if (value == null) {
      return const SizedBox(
        height: height,
        child: CustomPaint(painter: _PendingTrack(), size: Size.infinite),
      );
    }

    return ClipRRect(
      borderRadius: AppRadius.fullAll,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.gaugeTrack),
          child: Align(
            alignment: Alignment.centerLeft,
            // Jamais tout à fait zéro : une largeur nulle libère la
            // contrainte, et l'enfant se peindrait à sa taille naturelle.
            widthFactor: value.clamp(0.001, 1),
            child: ColoredBox(color: tint, child: const SizedBox.expand()),
          ),
        ),
      ),
    );
  }
}

class _PendingTrack extends CustomPainter {
  const _PendingTrack();

  static const double _dash = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.pendingTrack;
    for (var x = 0.0; x < size.width; x += _dash * 2) {
      final width = (size.width - x).clamp(0.0, _dash);
      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_PendingTrack oldDelegate) => false;
}
