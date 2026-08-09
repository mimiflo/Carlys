import 'dart:ui';

import 'package:carlys_mobile/design_system/scenes/heart_specks.dart';
import 'package:carlys_mobile/design_system/scenes/scene3d.dart';
import 'package:flutter_test/flutter_test.dart';

/// Particules blanches autour du cœur.
///
/// Ce qu'on vérifie ici, c'est le MODÈLE — position, vie, opacité — parce que
/// c'est là que sont les pièges : un cycle qui ne boucle pas téléporte les
/// particules toutes les trente secondes, et un vivier mal égrené les fait
/// toutes apparaître ensemble, ce qui n'est plus un accent mais une nuée.
void main() {
  SceneCamera cameraOf() => SceneCamera(
        fovDegrees: 32,
        x: 0.1,
        y: 0.15,
        z: 7.4,
        targetX: 0,
        targetY: -0.05,
        targetZ: 0,
      );

  /// Particules effectivement visibles à un instant donné.
  int visibleAt(double seconds) {
    var visible = 0;
    for (var i = 0; i < HeartSpecks.count; i++) {
      final state = HeartSpecks.stateAt(i, seconds);
      if (state != null && state.opacity > 0.02) {
        visible++;
      }
    }
    return visible;
  }

  test('le cycle boucle sans le moindre saut', () {
    // La scène rejoue son cycle toutes les trente secondes. Si l'état à 30 s
    // différait de l'état à 0, chaque particule se téléporterait à cet
    // instant — le défaut le plus visible qui soit sur un élément qui dérive
    // lentement.
    //
    // L'égalité se mesure à une tolérance serrée, PAS au bit près : le tour de
    // cycle passe par un `% 1` sur `1 + décalage`, dont le dernier bit diffère
    // de celui de `0 + décalage`. Un vrai saut vaudrait un dixième de cadre ;
    // ce qu'on tolère ici est mille millions de fois plus petit.
    for (var i = 0; i < HeartSpecks.count; i++) {
      final looped = HeartSpecks.stateAt(i, HeartSpecks.cycle);
      final origin = HeartSpecks.stateAt(i, 0);
      expect(looped == null, origin == null, reason: 'particule $i');
      if (looped == null || origin == null) {
        continue;
      }
      expect(
        looped.across,
        closeTo(origin.across, 1e-9),
        reason: 'particule $i',
      );
      expect(looped.fall, closeTo(origin.fall, 1e-9), reason: 'particule $i');
      expect(
        looped.opacity,
        closeTo(origin.opacity, 1e-9),
        reason: 'particule $i',
      );
    }

    // Et la continuité vaut aussi juste AVANT le rebouclage.
    for (var i = 0; i < HeartSpecks.count; i++) {
      final before = HeartSpecks.stateAt(i, HeartSpecks.cycle - 0.02);
      final after = HeartSpecks.stateAt(i, 0.02);
      if (before == null || after == null) {
        continue;
      }
      expect((before.fall - after.fall).abs(), lessThan(0.02));
    }
  });

  test('le rendu est déterministe', () {
    expect(HeartSpecks.stateAt(3, 12.5), HeartSpecks.stateAt(3, 12.5));
  });

  test('de temps en temps : jamais toutes ensemble, jamais le vide complet',
      () {
    var least = HeartSpecks.count;
    var most = 0;
    for (var step = 0; step < 600; step++) {
      final visible = visibleAt(step * HeartSpecks.cycle / 600);
      least = least < visible ? least : visible;
      most = most > visible ? most : visible;
    }

    // Un accent : quelques particules, jamais la moitié du vivier.
    expect(most, lessThanOrEqualTo(HeartSpecks.count ~/ 2));
    // Mais jamais rien non plus : la page ne doit pas paraître morte.
    expect(least, greaterThanOrEqualTo(1));
  });

  test('une particule naît et meurt en fondu', () {
    expect(HeartSpecks.envelope(0), 0);
    expect(HeartSpecks.envelope(1), 0);
    expect(HeartSpecks.envelope(0.5), 1);
    // Croissante sur la montée.
    expect(HeartSpecks.envelope(0.05), lessThan(HeartSpecks.envelope(0.12)));
  });

  test('aucune particule ne traverse la masse du cœur', () {
    // Sans tampon de profondeur, une particule dans le volume du cœur serait
    // dessinée soit entièrement devant, soit entièrement derrière — donc
    // fausse la moitié du temps. La bande est interdite, et ça se vérifie.
    for (var i = 0; i < HeartSpecks.count; i++) {
      final z = HeartSpecks.depthOf(i);
      expect(
        z <= HeartSpecks.behindZ || z >= HeartSpecks.frontZ,
        isTrue,
        reason: 'particule $i à z=$z',
      );
    }
  });

  test('la moitié du vivier passe devant, l\'autre derrière', () {
    final front = List.generate(HeartSpecks.count, HeartSpecks.isInFront)
        .where((f) => f)
        .length;
    expect(front, HeartSpecks.count ~/ 2);
  });

  test('les particules descendent', () {
    // Le sens de la dérive : haut → bas.
    final start = HeartSpecks.stateAt(0, 0.2);
    final later = HeartSpecks.stateAt(0, 4);
    expect(start, isNotNull);
    expect(later, isNotNull);
    expect(later!.fall, lessThan(start!.fall));
  });

  test('chaque passe ne dessine que son propre plan', () {
    // Le tri par plan n'est pas cosmétique : c'est lui qui fait passer des
    // particules DEVANT le cœur et d'autres derrière.
    const seconds = 6.0;
    final camera = cameraOf();

    final front = _Discs();
    HeartSpecks.paint(
      front,
      const Size(330, 330),
      camera,
      seconds: seconds,
      hero: false,
      front: true,
    );
    final behind = _Discs();
    HeartSpecks.paint(
      behind,
      const Size(330, 330),
      camera,
      seconds: seconds,
      hero: false,
      front: false,
    );

    var expectedFront = 0;
    var expectedBehind = 0;
    for (var i = 0; i < HeartSpecks.count; i++) {
      final state = HeartSpecks.stateAt(i, seconds);
      if (state == null || state.opacity <= 0) {
        continue;
      }
      if (HeartSpecks.isInFront(i)) {
        expectedFront++;
      } else {
        expectedBehind++;
      }
    }

    // Deux disques par particule : le halo, puis le point.
    expect(front.centers.length, expectedFront * 2);
    expect(behind.centers.length, expectedBehind * 2);
    // Les deux plans sont peuplés : sans ça, l'effet de profondeur n'existe
    // pas et l'égalité ci-dessus passerait sur un vivier tout entier d'un côté.
    expect(expectedFront, greaterThan(0));
    expect(expectedBehind, greaterThan(0));
  });

  test('une particule reste petite, et dans le cadre', () {
    // Deux garde-fous d'un coup : une particule projetée hors du canevas
    // serait du travail perdu (le conteneur découpe), et une particule qui
    // grossit cesse d'être une particule.
    const size = Size(330, 330);
    final camera = cameraOf();
    final discs = _Discs();
    for (var step = 0; step < 120; step++) {
      for (final front in const [true, false]) {
        HeartSpecks.paint(
          discs,
          size,
          camera,
          seconds: step * HeartSpecks.cycle / 120,
          hero: true,
          front: front,
        );
      }
    }

    for (final (center, _) in discs.centers) {
      expect(center.dx, inInclusiveRange(-size.width * 0.1, size.width * 1.1));
      expect(
        center.dy,
        inInclusiveRange(-size.height * 0.1, size.height * 1.1),
      );
    }

    // Le POINT (un disque sur deux : le halo est le premier) ne dépasse pas
    // six points de DIAMÈTRE sur une scène de 330 — relevé : 5,3 pour la plus
    // proche du premier plan.
    final cores = [
      for (final (index, disc) in discs.centers.indexed)
        if (index.isOdd) disc.$2,
    ];
    expect(cores, isNotEmpty);
    expect(cores.reduce((a, b) => a > b ? a : b) * 2, lessThan(6));
  });
}

/// Canevas qui relève les disques dessinés ; `noSuchMethod` absorbe tout le
/// reste de l'interface.
class _Discs implements Canvas {
  final List<(Offset, double)> centers = [];

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      centers.add((c, radius));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
