import 'dart:io';
import 'dart:math' as math;

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/welcome_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'ÉCRITURE NE SE POSE PAS SUR LA PERSONNE.
///
/// La page de marque écrit à gauche d'une photographie ancrée à droite. Rien
/// dans la mise en page ne les sépare : c'est le fondu du bord gauche du
/// cliché ([AthletePhotoFraming.fadeFrom]) qui garde le terrain libre. Trois
/// retouches ordinaires referment cette marge sans qu'aucun test ne rougisse :
/// rallonger une phrase du manifeste, grossir l'accroche, ou ramener le fondu
/// vers la gauche pour rendre la personne plus présente.
///
/// Ce fichier mesure donc les lignes avec les VRAIES fontes du bundle. Le
/// harnais de test dessine sinon des glyphes carrés, bien plus larges : les
/// largeurs seraient fausses, et le test mentirait dans les deux sens.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final family in const ['Inter', 'Oswald']) {
      final loader = FontLoader(family);
      final dir = Directory('assets/fonts');
      for (final file in dir.listSync().whereType<File>()) {
        final name = file.uri.pathSegments.last;
        if (!name.startsWith(family) || !name.endsWith('.ttf')) continue;
        // La graisse n'est pas exposée par `FontLoader` : c'est la première
        // fonte chargée qui sert de référence. On charge donc le GRAS en
        // tête — les lignes les plus longues sont celles de l'accroche, en
        // w700, et une mesure trop maigre laisserait passer un débordement.
        if (family == 'Inter' && !name.contains('Bold')) continue;
        loader.addFont(
          file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
    }
  });

  /// Un iPhone ordinaire, le format le plus contraint du parc : c'est là que
  /// la colonne de texte et la personne se disputent la largeur.
  const screen = Size(393, 852);
  final scale = WelcomeScreen.scaleFor(screen);

  /// Bord droit d'une ligne, en fraction de la largeur d'écran.
  double rightEdgeOf(String line, TextStyle style, {bool tilted = false}) {
    final painter = TextPainter(
      text: TextSpan(text: line, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = tilted ? _projected(painter.width) : painter.width;
    return (AppSpacing.gutter + width) / screen.width;
  }

  /// L'accroche : Inter 24 × échelle, w700, interlettrage resserré, posée en
  /// perspective — la rotation l'ÉLARGIT vers la droite, il faut en tenir
  /// compte ou la mesure sous-estime le débordement.
  final claim = AppTypography.title.copyWith(
    fontSize: 24 * scale,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.44,
  );

  /// Le credo : Inter 14 × échelle, sans interlettrage.
  ///
  /// Mesuré ENTIÈREMENT en gras, alors que seuls « TON » et « TA » le sont :
  /// `FontLoader` n'expose pas la graisse, c'est la première fonte chargée
  /// qui sert pour toutes. La mesure surestime donc la ligne d'environ deux
  /// points — une erreur du bon côté, qui ne peut que resserrer l'exigence.
  final creed = AppTypography.body.copyWith(
    fontSize: 14 * scale,
    fontWeight: FontWeight.w700,
  );

  const claimLines = [
    'SCULPTE',
    'TON PARCOURS.',
    'SIGNE TON',
    'CHEF-D’ŒUVRE.',
  ];
  const creedLines = [
    'Ton corps est TON œuvre.',
    'Ton parcours est TON histoire.',
    'Ta discipline est TA signature.',
  ];

  test('aucune ligne n’atteint la zone où la photographie peut apparaître', () {
    final edges = <String, double>{
      for (final line in claimLines)
        line: rightEdgeOf(line, claim, tilted: true),
      for (final line in creedLines) line: rightEdgeOf(line, creed),
    };

    for (final entry in edges.entries) {
      final clearance = AthletePhotoFraming.clearance(entry.value);
      expect(
        clearance,
        greaterThan(0),
        reason: '« ${entry.key} » finit à ${entry.value.toStringAsFixed(3)} '
            'alors que la photographie peut apparaître dès '
            '${AthletePhotoFraming.fadeFrom} : les mots se poseraient sur '
            'la personne.',
      );
    }
  });

  test('la marge reste confortable, pas juste positive', () {
    // Douze points d'écart suffisaient à la géométrie et se lisaient quand
    // même comme un contact : la lueur du cliché déborde, et l'ombre portée
    // de l'accroche aussi. On exige donc une vraie respiration.
    const minimum = 16 / 393;

    final longest = [
      for (final line in claimLines) rightEdgeOf(line, claim, tilted: true),
      for (final line in creedLines) rightEdgeOf(line, creed),
    ].reduce(math.max);

    expect(AthletePhotoFraming.clearance(longest), greaterThan(minimum));
  });

  test('la personne reste un grand élément de fond, pas une vignette', () {
    // Le garde-fou inverse : repousser le fondu résout le chevauchement mais
    // finit par reléguer la personne à droite. La planche validée la montre
    // pleinement dès les deux tiers de l'écran.
    expect(AthletePhotoFraming.fadeTo, lessThanOrEqualTo(0.75));
    expect(
      AthletePhotoFraming.fadeTo - AthletePhotoFraming.fadeFrom,
      greaterThan(0.1),
      reason: 'un fondu trop court dessine une coupe nette au lieu d’un bord',
    );
  });
}

/// Élargissement dû à la perspective de l'accroche (`rotateY(-8°)` avec
/// `m[3][2] = -1/700`, ancrée à gauche) : un point à `x` du bord gauche est
/// projeté un peu plus loin.
double _projected(double x) {
  const yaw = -8 * math.pi / 180;
  const perspective = -1 / 700;
  final projectedX = x * math.cos(yaw);
  final depth = -x * math.sin(yaw);
  return projectedX / (1 + perspective * depth);
}
