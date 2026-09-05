import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'majesty.dart';

/// LA PLAQUE : la fabrication d'un cran, sans son contenu.
///
/// Elle porte la surface, le filet, le grain et les équerres ; ce qu'on lit
/// dessus ne la regarde pas. Cette coupure permet de vérifier la montée en
/// majesté sur cinq plaques vides, et d'écrire la carte de titre sans se
/// préoccuper de son décor.
class MajestyPlate extends StatelessWidget {
  const MajestyPlate({
    required this.majesty,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final Majesty majesty;
  final Widget child;
  final EdgeInsets padding;

  /// Rayon de la carte de titre. Elle ne partage ce rayon avec AUCUNE autre
  /// carte de l'écran : c'est ce qui l'empêche d'être confondue avec une
  /// récompense.
  static const double radius = AppRadius.cardMain;

  @override
  Widget build(BuildContext context) {
    // La plaque du dernier cran vit DANS sa bordure en dégradé : elle est
    // d'un point plus petite, et son arrondi avec elle. Le décor doit suivre,
    // sinon le grain déborde d'un point et les équerres perdent leur jeu.
    final plateRadius = majesty.gradientEdge ? radius - 1 : radius;

    final plate = DecoratedBox(
      decoration: BoxDecoration(
        gradient: majesty.surface,
        borderRadius: BorderRadius.circular(plateRadius),
        border: majesty.border == null
            ? null
            : Border.all(color: majesty.border!, width: majesty.borderWidth),
      ),
      child: CustomPaint(
        painter: PlateOrnaments(majesty: majesty, radius: plateRadius),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (!majesty.gradientEdge) return plate;

    // Bordure d'UN pixel en dégradé : un conteneur extérieur dégradé, un
    // pixel de marge, la plaque à l'intérieur. Une bordure ne sait pas
    // porter un dégradé.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.majestyEdge,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(padding: const EdgeInsets.all(1), child: plate),
    );
  }
}

/// Le grain et les équerres. Peints, et non composés d'images : à cette
/// échelle, quelques lignes coûtent moins qu'une texture.
@visibleForTesting
class PlateOrnaments extends CustomPainter {
  const PlateOrnaments({required this.majesty, required this.radius});

  final Majesty majesty;

  /// Rayon de la plaque RÉELLEMENT peinte — 27 au dernier cran, 28 ailleurs.
  final double radius;

  /// Longueur d'une équerre.
  static const double _cornerLength = 12;

  /// Jeu voulu entre le sommet d'une équerre et l'ARRONDI de la plaque.
  ///
  /// C'est bien l'arrondi qu'il faut viser, et non le bord : dans un coin, la
  /// bordure s'éloigne du bord de `r − r/√2`, soit huit points pour un rayon
  /// de 28. Une équerre posée à dix points du bord ne gardait donc que deux
  /// points et demi de jeu avec la courbe, et s'y lisait comme collée.
  static const double cornerClearance = 9;

  /// Retrait d'une équerre depuis le bord, déduit du jeu ci-dessus.
  ///
  /// Le sommet est sur la diagonale du coin, à `(r − i)·√2` du centre de
  /// l'arrondi : lui laisser [cornerClearance] revient à poser
  /// `i = r − (r − jeu)/√2`. Calculé plutôt qu'écrit en dur, le jeu vaut pour
  /// les DEUX rayons — celui de la plaque et celui, plus petit d'un point, du
  /// dernier cran — et resterait juste si le rayon de la carte changeait.
  double get cornerInset => radius - (radius - cornerClearance) / math.sqrt2;

  /// Inclinaison du guillochage, en degrés. Franchement oblique : à 45° on
  /// lirait un motif de sécurité, ici on veut un grain de métal brossé.
  static const double _guillocheAngle = 126;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (majesty.halo) {
      // Un halo magenta rasant, à gauche : la plaque semble prendre la
      // lumière plutôt qu'être éclairée de face.
      canvas.drawCircle(
        Offset(0, size.height / 2),
        size.height,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  AppColors.magenta.withValues(alpha: 0.20),
                  AppColors.magenta.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(0, size.height / 2),
                  radius: size.height,
                ),
              ),
      );
    }

    if (majesty.guilloche case final spacing?) {
      canvas
        ..save()
        ..clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
      final paint = Paint()
        ..strokeWidth = 1
        ..color = AppColors.guilloche;
      final radians = _guillocheAngle * math.pi / 180;
      final dx = math.cos(radians);
      final dy = math.sin(radians);
      final span = size.width + size.height;
      for (var offset = -span; offset < span; offset += spacing) {
        canvas.drawLine(
          Offset(offset, 0),
          Offset(offset + dx * span, dy * span),
          paint,
        );
      }
      canvas.restore();
    }

    if (majesty.corners == 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = majesty.corners == 4 ? 1.5 : 1
      ..strokeCap = StrokeCap.round
      ..color = majesty.corners == 4
          ? AppColors.primaryLight
          : AppColors.majestyBorder;

    // Deux équerres en diagonale, quatre au dernier cran : le cadre se ferme
    // progressivement, il ne s'allume pas d'un coup.
    final inset = cornerInset;
    _corner(canvas, paint, Offset(inset, inset), 1, 1);
    _corner(
      canvas,
      paint,
      Offset(size.width - inset, size.height - inset),
      -1,
      -1,
    );
    if (majesty.corners < 4) return;
    _corner(canvas, paint, Offset(size.width - inset, inset), -1, 1);
    _corner(canvas, paint, Offset(inset, size.height - inset), 1, -1);
  }

  void _corner(
    Canvas canvas,
    Paint paint,
    Offset origin,
    double sx,
    double sy,
  ) {
    canvas
      ..drawLine(origin, origin.translate(_cornerLength * sx, 0), paint)
      ..drawLine(origin, origin.translate(0, _cornerLength * sy), paint);
  }

  @override
  bool shouldRepaint(PlateOrnaments old) =>
      old.majesty.tier != majesty.tier || old.radius != radius;
}
