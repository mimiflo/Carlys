/// Noyau de rendu 3D logiciel des scènes Carlys.
///
/// Porte fidèlement le modèle d'éclairage de la maquette (three.js
/// `MeshStandardMaterial` + `ACESFilmicToneMapping` + sortie sRGB) pour que le
/// cœur et l'hélice aient EXACTEMENT le rendu de la référence : matière lisse,
/// reflet spéculaire large, violet auto-éclairé.
///
/// Tout est calculé en espace LINÉAIRE ; la conversion sRGB n'a lieu qu'au
/// dernier moment, comme dans un moteur temps réel.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// sRGB (0..1) → linéaire.
double srgbToLinear(double c) =>
    c < 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// Bruit déterministe 0..1.
///
/// Les scènes n'utilisent JAMAIS `Random` : le rendu doit être reproductible
/// d'une image à l'autre — sinon les particules scintillent — et d'un test à
/// l'autre.
double sceneNoise(double n) {
  final s = math.sin(n * 127.1) * 43758.5453;
  return s - s.floorToDouble();
}

/// Linéaire (0..1) → sRGB.
double linearToSrgb(double c) =>
    c < 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

/// Table de conversion linéaire→sRGB en 8 bits.
///
/// La courbe est appelée trois fois par sommet : la tabuler évite des dizaines
/// de milliers d'exponentiations par image.
final Uint8List _srgbTable = () {
  const size = 4096;
  final table = Uint8List(size + 1);
  for (var i = 0; i <= size; i++) {
    table[i] = (linearToSrgb(i / size) * 255).round().clamp(0, 255);
  }
  return table;
}();

int _toSrgb8(double linear) {
  if (linear <= 0) {
    return 0;
  }
  if (linear >= 1) {
    return 255;
  }
  return _srgbTable[(linear * 4096).toInt()];
}

/// Couleur linéaire issue d'un entier 0xRRGGBB.
class LinearRgb {
  const LinearRgb(this.r, this.g, this.b);

  factory LinearRgb.fromHex(int hex) => LinearRgb(
        srgbToLinear(((hex >> 16) & 0xFF) / 255),
        srgbToLinear(((hex >> 8) & 0xFF) / 255),
        srgbToLinear((hex & 0xFF) / 255),
      );

  final double r;
  final double g;
  final double b;

  LinearRgb scaled(double k) => LinearRgb(r * k, g * k, b * k);

  LinearRgb lerpTo(LinearRgb other, double t) => LinearRgb(
        r + (other.r - r) * t,
        g + (other.g - g) * t,
        b + (other.b - b) * t,
      );
}

/// Nature d'une source lumineuse.
enum LightKind { ambient, point, directional }

/// Source lumineuse en unités physiques (comme three.js sans `useLegacyLights`).
class SceneLight {
  const SceneLight.ambient(this.color)
      : kind = LightKind.ambient,
        intensity = 1,
        x = 0,
        y = 0,
        z = 0,
        cutoff = 0;

  /// Lampe ponctuelle : l'éclairement décroît en 1/d², borné par [cutoff].
  const SceneLight.point(
    this.color,
    this.intensity, {
    required this.x,
    required this.y,
    required this.z,
    this.cutoff = 0,
  }) : kind = LightKind.point;

  /// Lampe directionnelle : [x], [y], [z] est la position visée depuis
  /// l'origine, donc la direction d'où vient la lumière.
  const SceneLight.directional(
    this.color,
    this.intensity, {
    required this.x,
    required this.y,
    required this.z,
  })  : kind = LightKind.directional,
        cutoff = 0;

  final LightKind kind;
  final LinearRgb color;
  final double intensity;
  final double x;
  final double y;
  final double z;
  final double cutoff;
}

/// Matériau standard (métallique / rugosité), couleurs en linéaire.
class StandardMaterial {
  StandardMaterial({
    required this.base,
    required this.emissive,
    required this.roughness,
    required this.metalness,
    required this.opacity,
    this.emissiveIntensity = 1,
  });

  final LinearRgb base;
  final LinearRgb emissive;
  double emissiveIntensity;
  final double roughness;
  final double metalness;
  final double opacity;
}

/// Rasteriseur d'éclairage : une instance par scène, réutilisée à chaque image.
class SceneShader {
  SceneShader({
    required this.lights,
    required this.exposure,
    required this.cameraX,
    required this.cameraY,
    required this.cameraZ,
  }) {
    // Les lampes directionnelles ont une direction constante : la normaliser
    // à chaque sommet coûtait une racine carrée pour rien.
    for (final light in lights) {
      if (light.kind != LightKind.directional) {
        _directions.add(const [0.0, 0.0, 0.0]);
        continue;
      }
      final d = math.sqrt(
        light.x * light.x + light.y * light.y + light.z * light.z,
      );
      _directions.add([light.x / d, light.y / d, light.z / d]);
    }
  }

  final List<List<double>> _directions = [];

  final List<SceneLight> lights;
  final double exposure;
  final double cameraX;
  final double cameraY;
  final double cameraZ;

  /// Éclaire un point de surface et renvoie la couleur ARGB 32 bits.
  ///
  /// [nx], [ny], [nz] : normale unitaire en espace monde.
  /// [px], [py], [pz] : position en espace monde.
  int shade(
    double nx,
    double ny,
    double nz,
    double px,
    double py,
    double pz,
    StandardMaterial m,
  ) {
    // Vue
    var vx = cameraX - px;
    var vy = cameraY - py;
    var vz = cameraZ - pz;
    final vLen = math.sqrt(vx * vx + vy * vy + vz * vz);
    if (vLen > 1e-9) {
      vx /= vLen;
      vy /= vLen;
      vz /= vLen;
    }

    // Composantes du matériau
    final oneMinusMetal = 1 - m.metalness;
    final dr = m.base.r * oneMinusMetal;
    final dg = m.base.g * oneMinusMetal;
    final db = m.base.b * oneMinusMetal;
    final f0r = 0.04 + (m.base.r - 0.04) * m.metalness;
    final f0g = 0.04 + (m.base.g - 0.04) * m.metalness;
    final f0b = 0.04 + (m.base.b - 0.04) * m.metalness;
    final alpha = m.roughness * m.roughness;
    final a2 = alpha * alpha;

    var dotNV = nx * vx + ny * vy + nz * vz;
    if (dotNV < 1e-4) {
      dotNV = 1e-4;
    }

    var outR = m.emissive.r * m.emissiveIntensity;
    var outG = m.emissive.g * m.emissiveIntensity;
    var outB = m.emissive.b * m.emissiveIntensity;

    for (var index = 0; index < lights.length; index++) {
      final light = lights[index];
      if (light.kind == LightKind.ambient) {
        // Diffus indirect : irradiance * albedo / π
        outR += light.color.r * dr * _invPi;
        outG += light.color.g * dg * _invPi;
        outB += light.color.b * db * _invPi;
        continue;
      }

      double lx;
      double ly;
      double lz;
      var attenuation = 1.0;

      if (light.kind == LightKind.point) {
        lx = light.x - px;
        ly = light.y - py;
        lz = light.z - pz;
        final d = math.sqrt(lx * lx + ly * ly + lz * lz);
        if (d < 1e-6) {
          continue;
        }
        lx /= d;
        ly /= d;
        lz /= d;
        attenuation = 1 / math.max(d * d, 0.01);
        if (light.cutoff > 0) {
          final ratio = d / light.cutoff;
          final r4 = ratio * ratio * ratio * ratio;
          final falloff = (1 - r4).clamp(0.0, 1.0);
          attenuation *= falloff * falloff;
        }
      } else {
        final dir = _directions[index];
        lx = dir[0];
        ly = dir[1];
        lz = dir[2];
      }

      final dotNL = nx * lx + ny * ly + nz * lz;
      if (dotNL <= 0) {
        continue;
      }

      final k = light.intensity * attenuation * dotNL;
      final ir = light.color.r * k;
      final ig = light.color.g * k;
      final ib = light.color.b * k;

      // Diffus lambertien
      outR += ir * dr * _invPi;
      outG += ig * dg * _invPi;
      outB += ib * db * _invPi;

      // Spéculaire GGX (D · V · F)
      var hx = lx + vx;
      var hy = ly + vy;
      var hz = lz + vz;
      final hLen = math.sqrt(hx * hx + hy * hy + hz * hz);
      if (hLen < 1e-9) {
        continue;
      }
      hx /= hLen;
      hy /= hLen;
      hz /= hLen;

      final dotNH = math.max(nx * hx + ny * hy + nz * hz, 0.0);
      final dotVH = math.max(vx * hx + vy * hy + vz * hz, 0.0);

      final denom = dotNH * dotNH * (a2 - 1) + 1;
      final dTerm = _invPi * a2 / math.max(denom * denom, 1e-9);

      final gv = dotNL * math.sqrt(a2 + (1 - a2) * dotNV * dotNV);
      final gl = dotNV * math.sqrt(a2 + (1 - a2) * dotNL * dotNL);
      final vTerm = 0.5 / math.max(gv + gl, 1e-6);

      final oneMinusVH = 1 - dotVH;
      final vh2 = oneMinusVH * oneMinusVH;
      final fresnel = vh2 * vh2 * oneMinusVH;
      final fr = f0r + (1 - f0r) * fresnel;
      final fg = f0g + (1 - f0g) * fresnel;
      final fb = f0b + (1 - f0b) * fresnel;

      final spec = vTerm * dTerm;
      outR += ir * fr * spec;
      outG += ig * fg * spec;
      outB += ib * fb * spec;
    }

    return _encode(outR, outG, outB, m.opacity);
  }

  /// Tone mapping ACES filmique puis encodage sRGB, comme le moteur de la
  /// maquette (`toneMapping = ACESFilmicToneMapping`, `outputColorSpace = sRGB`).
  int _encode(double r, double g, double b, double opacity) {
    final k = exposure / 0.6;
    var cr = r * k;
    var cg = g * k;
    var cb = b * k;

    // Matrice d'entrée ACES
    final ir = 0.59719 * cr + 0.35458 * cg + 0.04823 * cb;
    final ig = 0.07600 * cr + 0.90834 * cg + 0.01566 * cb;
    final ib = 0.02840 * cr + 0.13383 * cg + 0.83777 * cb;

    double fit(double v) {
      final a = v * (v + 0.0245786) - 0.000090537;
      final d = v * (0.983729 * v + 0.432951) + 0.238081;
      return a / d;
    }

    final fr = fit(ir);
    final fg = fit(ig);
    final fb = fit(ib);

    // Matrice de sortie ACES
    cr = 1.60475 * fr - 0.53108 * fg - 0.07367 * fb;
    cg = -0.10208 * fr + 1.10813 * fg - 0.00605 * fb;
    cb = -0.00327 * fr - 0.07276 * fg + 1.07602 * fb;

    final o8 = (opacity.clamp(0.0, 1.0) * 255).round();
    return (o8 << 24) |
        (_toSrgb8(cr) << 16) |
        (_toSrgb8(cg) << 8) |
        _toSrgb8(cb);
  }
}

const double _invPi = 1 / math.pi;

/// Rotation d'Euler dans l'ordre XYZ de three.js : R = Rx · Ry · Rz.
class EulerRotation {
  EulerRotation(double x, double y, double z) {
    final a = math.cos(x), b = math.sin(x);
    final c = math.cos(y), d = math.sin(y);
    final e = math.cos(z), f = math.sin(z);

    final ae = a * e, af = a * f, be = b * e, bf = b * f;

    m00 = c * e;
    m01 = -c * f;
    m02 = d;
    m10 = af + be * d;
    m11 = ae - bf * d;
    m12 = -b * c;
    m20 = bf - ae * d;
    m21 = be + af * d;
    m22 = a * c;
  }

  late final double m00, m01, m02, m10, m11, m12, m20, m21, m22;

  double rotX(double x, double y, double z) => m00 * x + m01 * y + m02 * z;
  double rotY(double x, double y, double z) => m10 * x + m11 * y + m12 * z;
  double rotZ(double x, double y, double z) => m20 * x + m21 * y + m22 * z;
}

/// Caméra en perspective avec visée, calquée sur `PerspectiveCamera` + `lookAt`.
class SceneCamera {
  SceneCamera({
    required this.fovDegrees,
    required this.x,
    required this.y,
    required this.z,
    required double targetX,
    required double targetY,
    required double targetZ,
  }) {
    // Base de vue : z regarde vers l'arrière (convention OpenGL).
    var zx = x - targetX, zy = y - targetY, zz = z - targetZ;
    final zl = math.sqrt(zx * zx + zy * zy + zz * zz);
    zx /= zl;
    zy /= zl;
    zz /= zl;
    // up = (0, 1, 0) ; x = up × z
    var xx = zz * 0.0 - 0.0 * zy;
    var xy = 0.0 * zx - zz * 0.0;
    var xz = 0.0 * zy - 0.0 * zx;
    xx = 1.0 * zz - 0.0 * zy;
    xy = 0.0 * zx - 0.0 * zz;
    xz = 0.0 * zy - 1.0 * zx;
    final xl = math.sqrt(xx * xx + xy * xy + xz * xz);
    xx /= xl;
    xy /= xl;
    xz /= xl;
    // y = z × x
    final yx = zy * xz - zz * xy;
    final yy = zz * xx - zx * xz;
    final yz = zx * xy - zy * xx;

    // Champs PLATS (pas de listes) : la projection tourne dans la boucle de
    // sommets, chaque indirection s'y paie des milliers de fois par image.
    _r00 = xx;
    _r01 = xy;
    _r02 = xz;
    _r10 = yx;
    _r11 = yy;
    _r12 = yz;
    _r20 = zx;
    _r21 = zy;
    _r22 = zz;
    _tanHalfFov = math.tan(fovDegrees * math.pi / 360);
  }

  final double fovDegrees;
  final double x;
  final double y;
  final double z;
  late final double _r00, _r01, _r02, _r10, _r11, _r12, _r20, _r21, _r22;
  late final double _tanHalfFov;

  /// Projette un point monde en coordonnées écran (pixels), avec la
  /// profondeur de vue (négative devant la caméra).
  ({double sx, double sy, double viewZ}) project(
    double px,
    double py,
    double pz,
    double width,
    double height,
  ) {
    final dx = px - x, dy = py - y, dz = pz - z;
    final vx = _r00 * dx + _r01 * dy + _r02 * dz;
    final vy = _r10 * dx + _r11 * dy + _r12 * dz;
    final vz = _r20 * dx + _r21 * dy + _r22 * dz;

    final depth = vz < -1e-4 ? -vz : 1e-4;
    final ndcY = vy / (depth * _tanHalfFov);
    final ndcX = vx / (depth * _tanHalfFov * (width / height));
    return (
      sx: width * 0.5 * (1 + ndcX),
      sy: height * 0.5 * (1 - ndcY),
      viewZ: vz,
    );
  }

  /// Variante SANS ALLOCATION de [project], pour les boucles de sommets.
  ///
  /// L'enregistrement rendu par [project] est un objet : à douze mille
  /// sommets par image et trente images par seconde, cela fait des centaines
  /// de milliers d'allocations par seconde — autant de travail offert au
  /// ramasse-miettes, donc des à-coups sur les téléphones modestes. Ici, x et
  /// y écran s'écrivent dans [screen] (2 cases par sommet) et la profondeur
  /// de vue dans [depth], des tampons déjà alloués par le maillage.
  void projectInto(
    Float32List screen,
    Float32List depth,
    int index,
    double px,
    double py,
    double pz,
    double width,
    double height,
  ) {
    final dx = px - x, dy = py - y, dz = pz - z;
    final vx = _r00 * dx + _r01 * dy + _r02 * dz;
    final vy = _r10 * dx + _r11 * dy + _r12 * dz;
    final vz = _r20 * dx + _r21 * dy + _r22 * dz;

    final d = vz < -1e-4 ? -vz : 1e-4;
    final ndcY = vy / (d * _tanHalfFov);
    final ndcX = vx / (d * _tanHalfFov * (width / height));
    screen[index * 2] = width * 0.5 * (1 + ndcX);
    screen[index * 2 + 1] = height * 0.5 * (1 - ndcY);
    depth[index] = vz;
  }

  /// Facteur pixels-par-unité-monde à une profondeur donnée (taille des points).
  double pixelsPerUnit(double depth, double height) =>
      height * 0.5 / (depth.abs() * _tanHalfFov);
}
