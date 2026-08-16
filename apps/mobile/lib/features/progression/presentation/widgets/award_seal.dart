import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';

/// LE SCEAU : une SILHOUETTE, pas une pastille colorée.
///
/// C'est la forme qui porte le sens — écu, disque à ruban, feuille cachetée,
/// plaque, cartouche. La version précédente distinguait les récompenses par
/// leur teinte de remplissage : cinq ronds identiques, qu'on ne pouvait pas
/// nommer sans lire la légende.
///
/// Construction constante, quelle que soit la forme : la silhouette est
/// remplie du dégradé, puis LA MÊME silhouette, insérée de deux pixels, est
/// remplie de la surface. Le filet naît de la différence, comme sur un sceau
/// frappé — jamais d'un trait dessiné par-dessus.
///
/// Deux tailles seulement. À 34, les ornements internes disparaissent : la
/// silhouette suffit, et un détail de deux pixels n'est plus qu'une salissure.
class AwardSeal extends StatelessWidget {
  const AwardSeal({
    required this.kind,
    this.size = large,
    this.figure,
    this.earned = true,
    super.key,
  });

  /// Vitrine et bloc compact.
  static const double large = 56;

  /// Ligne de liste.
  static const double small = 34;

  final RewardKind kind;
  final double size;

  /// Ce qui est frappé au centre : « 80 » pour un record, « IV » pour un
  /// titre. Les autres formes portent un glyphe.
  final String? figure;

  /// Pas encore gagné : la silhouette est là, elle n'est pas frappée.
  final bool earned;

  bool get _isLarge => size >= large;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: SealPainter(kind: kind, size: size, earned: earned),
        child: Center(child: _mark()),
      ),
    );
  }

  Widget _mark() {
    final text = figure;
    if (text != null) {
      return Text(
        text,
        style: (_isLarge ? AppTypography.metricS : AppTypography.labelMono)
            .copyWith(
          fontSize: _isLarge ? (kind == RewardKind.titre ? 16 : 15) : 11,
          color: AppColors.primaryLight,
        ),
      );
    }
    // Le certificat ne porte AUCUNE marque : ses filets de texte et son
    // cachet disent déjà ce qu'il est.
    if (kind == RewardKind.certificat) return const SizedBox.shrink();
    return Icon(
      _glyph(kind),
      size: _isLarge ? 22 : 15,
      color: AppColors.primaryLight,
    );
  }

  static IconData _glyph(RewardKind kind) => switch (kind) {
        RewardKind.badge => AppIcons.brandAcademy,
        RewardKind.medaille => AppIcons.medal,
        RewardKind.certificat => AppIcons.certificate,
        RewardKind.record => AppIcons.record,
        RewardKind.titre => AppIcons.crown,
      };
}

/// Le peintre des cinq silhouettes.
///
/// Un seul peintre paramétré, et non cinq : les cinq formes partagent leur
/// construction (remplissage, insertion, filet), seule leur ligne diffère.
@visibleForTesting
class SealPainter extends CustomPainter {
  const SealPainter({
    required this.kind,
    required this.size,
    this.earned = true,
  });

  final RewardKind kind;
  final double size;
  final bool earned;

  bool get _isLarge => size >= AwardSeal.large;

  /// Épaisseur du filet : deux pixels à 56, un et demi à 34.
  double get _rule => _isLarge ? 2 : 1.5;

  @override
  void paint(Canvas canvas, Size box) {
    final rect = Offset.zero & box;

    // Le ruban de la médaille passe DERRIÈRE le disque : il se peint donc en
    // premier, sinon le disque le recouvrirait.
    if (kind == RewardKind.medaille && _isLarge) {
      _paintRibbon(canvas, box);
    }

    final outline = _outline(box);
    canvas.drawPath(outline, Paint()..shader = _fill(rect));

    // La même forme, rentrée : c'est le creux qui fait le filet.
    canvas.drawPath(
      _inset(outline, box, _rule),
      Paint()..color = AppColors.darkSurface,
    );

    if (!_isLarge) return;
    switch (kind) {
      case RewardKind.medaille:
        _paintInnerRing(canvas, box);
      case RewardKind.certificat:
        _paintCertificateLines(canvas, box);
      case RewardKind.titre:
        _paintDoubleFrame(canvas, box, outline);
      case RewardKind.badge:
      case RewardKind.record:
        break;
    }
  }

  Shader _fill(Rect rect) {
    if (!earned) {
      // Pas encore frappé : la silhouette existe, elle n'a pas sa matière.
      return const LinearGradient(
        colors: [AppColors.majestyBorder, AppColors.majestyBorder],
      ).createShader(rect);
    }
    return (kind == RewardKind.titre
            ? AppColors.sealTitleFill
            : AppColors.sealFill)
        .createShader(rect);
  }

  /// La silhouette, exposée pour que les tests puissent vérifier que les cinq
  /// formes diffèrent réellement — un dessin ne se relit pas autrement.
  @visibleForTesting
  Path outline(Size box) => _outline(box);

  /// La ligne extérieure, en fractions de la boîte.
  Path _outline(Size box) {
    final w = box.width;
    final h = box.height;
    Path fromPoints(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx * w, points.first.dy * h);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx * w, point.dy * h);
      }
      return path..close();
    }

    return switch (kind) {
      // Écu.
      RewardKind.badge => fromPoints(const [
          Offset(.5, 0),
          Offset(1, .20),
          Offset(1, .62),
          Offset(.5, 1),
          Offset(0, .62),
          Offset(0, .20),
        ]),
      // Disque.
      RewardKind.medaille => Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(w / 2, h * (_isLarge ? .56 : .5)),
            radius: w * (_isLarge ? .25 : .5),
          ),
        ),
      // Feuille dont le bas est déchiré en deux pointes.
      RewardKind.certificat => fromPoints(const [
          Offset(.11, 0),
          Offset(.89, 0),
          Offset(.89, 1),
          Offset(.70, .88),
          Offset(.5, 1),
          Offset(.30, .88),
          Offset(.11, 1),
        ]),
      // Plaque à pointes latérales.
      RewardKind.record => fromPoints(const [
          Offset(.12, .16),
          Offset(.88, .16),
          Offset(1, .5),
          Offset(.88, .84),
          Offset(.12, .84),
          Offset(0, .5),
        ]),
      // Cartouche octogonale.
      RewardKind.titre => fromPoints(const [
          Offset(.30, 0),
          Offset(.70, 0),
          Offset(1, .30),
          Offset(1, .70),
          Offset(.70, 1),
          Offset(.30, 1),
          Offset(0, .70),
          Offset(0, .30),
        ]),
    };
  }

  /// La même forme, rentrée de [inset] depuis son centre.
  ///
  /// Une homothétie plutôt qu'un décalage de contour : à ces tailles la
  /// différence ne se voit pas, et elle évite un calcul de normales pour
  /// six segments.
  Path _inset(Path path, Size box, double inset) {
    final center = Offset(box.width / 2, box.height / 2);
    final scale = 1 - (inset * 2) / box.shortestSide;
    return path.transform(
      (Matrix4.identity()
            ..translateByDouble(center.dx, center.dy, 0, 1)
            ..scaleByDouble(scale, scale, 1, 1)
            ..translateByDouble(-center.dx, -center.dy, 0, 1))
          .storage,
    );
  }

  void _paintRibbon(Canvas canvas, Size box) {
    final w = box.width;
    final h = box.height;
    final ribbon = Path()
      ..moveTo(w * .30, 0)
      ..lineTo(w * .70, 0)
      ..lineTo(w * .70, h * .46)
      ..lineTo(w * .50, h * .32)
      ..lineTo(w * .30, h * .46)
      ..close();
    canvas.drawPath(
      ribbon,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryDark, AppColors.primaryDeep],
        ).createShader(Offset.zero & box),
    );
  }

  void _paintInnerRing(Canvas canvas, Size box) {
    final center = Offset(box.width / 2, box.height * .56);
    final radius = box.width * .18;
    // Un anneau en tirets : la marque d'un disque frappé, pas d'un jeton.
    const segments = 18;
    for (var i = 0; i < segments; i++) {
      final start = i * 2 * 3.14159 / segments;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        3.14159 / segments,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.engravedRule,
      );
    }
  }

  void _paintCertificateLines(Canvas canvas, Size box) {
    final w = box.width;
    final h = box.height;
    final paint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.engravedRule;
    // Trois filets : l'idée d'un texte, pas un texte illisible.
    for (final line in const [(.30, .58), (.42, .46), (.54, .34)]) {
      canvas.drawLine(
        Offset(w * .26, h * line.$1),
        Offset(w * (.26 + line.$2), h * line.$1),
        paint,
      );
    }
    // Le cachet : la seule occurrence de magenta d'un sceau.
    canvas.drawCircle(
      Offset(w * .70, h * .70),
      w * .11,
      Paint()..color = AppColors.magenta,
    );
  }

  void _paintDoubleFrame(Canvas canvas, Size box, Path outline) {
    canvas.drawPath(
      _inset(outline, box, _rule + 5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.engravedRule,
    );
  }

  @override
  bool shouldRepaint(SealPainter old) =>
      old.kind != kind || old.size != size || old.earned != earned;
}
