import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'brand_signature.dart';

/// L'accroche de la page de marque, en relief.
///
/// Les coupes de lignes sont ÉCRITES : c'est une accroche d'affiche, son rythme
/// fait partie du message et ne se laisse pas au retour à la ligne automatique.
class BrandClaim extends StatelessWidget {
  const BrandClaim({this.scale = 1, super.key});

  /// Échelle du bloc, voir [WelcomeScreen.scaleFor].
  final double scale;

  /// Extrusion : cinq ombres PLEINES (sans flou) décalées d'un pixel chacune,
  /// puis une ombre portée. C'est ce qui donne l'épaisseur ; les remplacer par
  /// un flou unique aplatirait le relief.
  ///
  /// **La liste est à l'ENVERS de la référence CSS, volontairement.** CSS
  /// empile les `text-shadow` de haut en bas — la première déclarée est la plus
  /// haute — quand Flutter les peint dans l'ordre, la dernière par-dessus.
  /// Recopiée telle quelle, la pile s'inversait : la teinte la plus sombre
  /// recouvrait les autres et le relief virait au noir au lieu de s'éclaircir
  /// près des lettres.
  static const List<Shadow> _extrusion = [
    Shadow(color: Color(0xD1000000), offset: Offset(6, 7), blurRadius: 13),
    Shadow(color: Color(0xFF1A1420), offset: Offset(5, 5)),
    Shadow(color: Color(0xFF251C2E), offset: Offset(4, 4)),
    Shadow(color: Color(0xFF31253E), offset: Offset(3, 3)),
    Shadow(color: Color(0xFF3D2F4E), offset: Offset(2, 2)),
    Shadow(color: Color(0xFF4A3A5E), offset: Offset(1, 1)),
  ];

  /// `perspective(700px) rotateY(-8deg) rotateX(4deg)`, origine gauche/centre.
  ///
  /// Les angles sont ceux du CSS : les deux repères tournent de la même façon.
  /// Ce qui diffère, c'est la PERSPECTIVE — CSS pose `m[3][2] = -1/d`, si bien
  /// qu'un point ramené vers l'œil GRANDIT. L'idiome Flutter habituel écrit
  /// `1/d`, qui inverse la profondeur : recopié tel quel, le relief poussait
  /// l'accroche vers l'arrière et elle rétrécissait vers la droite au lieu de
  /// s'élargir. Écart mesuré sur la référence avant/après : −11 % → −4 %, le
  /// reste tenant aux fontes (Inter variable côté web, statique ici).
  static const double _perspective = -1 / 700;
  static const double _yawDegrees = -8;
  static const double _pitchDegrees = 4;

  static const double _size = 24;

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.title.copyWith(
      fontSize: _size * scale,
      height: 1.24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.44,
      color: AppColors.neutral0,
      shadows: _extrusion,
    );

    return Transform(
      alignment: Alignment.centerLeft,
      transform: Matrix4.identity()
        ..setEntry(3, 2, _perspective)
        ..rotateY(_yawDegrees * math.pi / 180)
        ..rotateX(_pitchDegrees * math.pi / 180),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'SCULPTE\nTON PARCOURS.\nSIGNE TON\n'),
            TextSpan(
              text: 'CHEF-D’ŒUVRE.',
              style: base.copyWith(color: AppColors.signatureMid),
            ),
          ],
        ),
        style: base,
      ),
    );
  }
}

/// Les trois affirmations qui disent à qui appartient le parcours.
class BrandCreed extends StatelessWidget {
  const BrandCreed({this.scale = 1, super.key});

  /// Échelle du bloc, voir [WelcomeScreen.scaleFor].
  final double scale;

  static const List<(String, String, String)> _lines = [
    ('Ton corps est ', 'TON', ' œuvre.'),
    ('Ton parcours est ', 'TON', ' histoire.'),
    ('Ta discipline est ', 'TA', ' signature.'),
  ];

  static const double _size = 14;

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.body.copyWith(
      fontSize: _size * scale,
      height: 1.75,
      color: AppColors.darkTextSecondary,
      shadows: BrandSignature.blockShadows,
    );
    final strong = base.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.neutral0,
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
                TextSpan(text: accent, style: strong),
                TextSpan(text: after),
              ],
            ),
            style: base,
          ),
      ],
    );
  }
}

/// Cinq barres décroissantes : une progression, réduite à son signe.
///
/// Purement graphique — elle ne mesure rien et ne prétend rien mesurer.
class BrandProgressMotif extends StatelessWidget {
  const BrandProgressMotif({this.scale = 1, super.key});

  /// Échelle du bloc, voir [WelcomeScreen.scaleFor].
  final double scale;

  static const double _height = 4;
  static const double _gap = 9;

  static const List<double> _widths = [40, 24, 14, 8, 5];

  @override
  Widget build(BuildContext context) {
    final fills = <Decoration>[
      const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.signatureStart, AppColors.signatureMid],
        ),
        borderRadius: AppRadius.xsAll,
      ),
      const BoxDecoration(
        color: AppColors.signatureMid,
        borderRadius: AppRadius.xsAll,
      ),
      BoxDecoration(
        color: AppColors.signatureEnd.withValues(alpha: 0.75),
        borderRadius: AppRadius.xsAll,
      ),
      BoxDecoration(
        color: AppColors.signatureEnd.withValues(alpha: 0.45),
        borderRadius: AppRadius.xsAll,
      ),
      BoxDecoration(
        color: AppColors.darkTextSecondary.withValues(alpha: 0.35),
        borderRadius: AppRadius.xsAll,
      ),
    ];

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, width) in _widths.indexed) ...[
            if (index > 0) SizedBox(width: _gap * scale),
            SizedBox(
              width: width * scale,
              height: _height,
              child: DecoratedBox(decoration: fills[index]),
            ),
          ],
        ],
      ),
    );
  }
}
