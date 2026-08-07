import 'dart:math' as math;
import 'dart:ui';

/// Éclairage commun des scènes 3D (handoff/animations-3d.md) :
/// ambiante violette, ponctuelle primary, ponctuelle accent, contre-jour
/// blanc. C'est ce trio qui donne le volume — ne pas le simplifier.
class SceneLightRig {
  const SceneLightRig({required this.hero});

  final bool hero;

  static const _ambientColor = (r: 0.42, g: 0.42, b: 1.0); // #6A6AFF
  static const _primary = (r: 0.36, g: 0.36, b: 0.96); // #5B5BF6
  static const _accent = (r: 0.78, g: 0.96, b: 0.20); // #C6F432
  static const _white = (r: 1.0, g: 1.0, b: 1.0);

  // Directions normalisées des sources (positions du handoff).
  static final _primaryDir = _normalize(4, 5, 7);
  static final _accentDir = _normalize(-5, -4, 5);
  static final _rimDir = _normalize(-2, 3, -6);

  static (double, double, double) _normalize(double x, double y, double z) {
    final length = math.sqrt(x * x + y * y + z * z);
    return (x / length, y / length, z / length);
  }

  /// Éclaire une normale (espace vue) pour une couleur de base et une
  /// émission donnée. Retourne des composantes 0..1.
  (double, double, double) shade({
    required double nx,
    required double ny,
    required double nz,
    required (double, double, double) base,
    required double emissive,
  }) {
    final ambient = hero ? 0.5 : 0.7;
    final primaryIntensity = hero ? 0.85 : 0.55;
    final accentIntensity = hero ? 0.45 : 0.25;
    final rimIntensity = hero ? 0.5 : 0.25;

    double dot((double, double, double) dir) {
      final value = nx * dir.$1 + ny * dir.$2 + nz * dir.$3;
      return value > 0 ? value : 0;
    }

    final primary = dot(_primaryDir) * primaryIntensity;
    final accent = dot(_accentDir) * accentIntensity;
    final rim = dot(_rimDir) * rimIntensity;

    double channel(
      double baseChannel,
      double ambientChannel,
      double primaryChannel,
      double accentChannel,
      double whiteChannel,
    ) {
      final lit =
          baseChannel * (ambient * ambientChannel + primary * primaryChannel) +
              accent * accentChannel * 0.5 +
              rim * whiteChannel * 0.35 +
              emissive * primaryChannel;
      return lit.clamp(0.0, 1.0);
    }

    return (
      channel(base.$1, _ambientColor.r, _primary.r, _accent.r, _white.r),
      channel(base.$2, _ambientColor.g, _primary.g, _accent.g, _white.g),
      channel(base.$3, _ambientColor.b, _primary.b, _accent.b, _white.b),
    );
  }
}

/// Encode des composantes 0..1 en couleur ARGB pour `Vertices.raw`.
int packColor(double r, double g, double b, double alpha) {
  return (((alpha * 255).round() & 0xff) << 24) |
      (((r * 255).round() & 0xff) << 16) |
      (((g * 255).round() & 0xff) << 8) |
      ((b * 255).round() & 0xff);
}

/// Projette un point (espace vue, caméra en +Z) vers le canvas.
/// FOV fixe (~30°) : `scale = focale / (focale - z)`.
Offset project(
  double x,
  double y,
  double z, {
  required double focal,
  required Size size,
  required double worldScale,
}) {
  final perspective = focal / (focal - z);
  return Offset(
    size.width / 2 + x * worldScale * perspective,
    size.height / 2 - y * worldScale * perspective,
  );
}

/// Bruit déterministe 0..1 par indice — jamais de Random() dans les
/// scènes : le rendu doit être reproductible en test et en golden.
double hashNoise(int index) {
  var h = index * 2654435761;
  h = (h ^ (h >> 16)) * 0x45d9f3b;
  h = (h ^ (h >> 16)) & 0x7fffffff;
  return h / 0x7fffffff;
}
