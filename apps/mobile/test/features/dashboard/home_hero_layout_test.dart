import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/dashboard/domain/entities/daily_quote.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/daily_quote_card.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/home_header.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/home_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enlarged_text.dart';

/// LA ZONE HAUTE DE L'ACCUEIL, en texte agrandi et au lecteur d'écran.
///
/// L'en-tête avait une hauteur FIXE de 89 points, calculée pour le texte
/// ×1 : dès ×1,15 sur 360 points, la seconde ligne de la phrase d'état se
/// peignait par-dessus la citation (10 points de trop, 87 en ×2 sur 320).
/// Et sa sémantique n'avait pas de frontière : la date, la salutation, la
/// phrase d'état et la citation se lisaient comme UN bouton « Profil », qu'un
/// double-tap pour relire ouvrait.
void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    // Le cœur bat en boucle : animations réduites.
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  const citation = DailyQuote(
    text: 'Le tempo est une charge invisible.',
    value: CarlysValue.constance,
  );

  Widget accueil({
    String subtitle = 'Récupération faite : le créneau est bon.',
    String displayName = 'Maximilien Durand',
  }) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HomeHero(
            displayName: displayName,
            subtitle: subtitle,
            quote: citation,
          ),
          const Text('Série de constance'),
        ],
      ),
    ),
  );

  // Les phrases d'état de `homeSubtitleProvider`, la plus longue comprise.
  const phrases = [
    'Séance en cours.',
    'Séance faite aujourd’hui. Beau travail.',
    'Ton parcours commence aujourd’hui.',
    'Ton corps encaisse encore la dernière séance.',
    'Récupération faite : le créneau est bon.',
    '12 jours de repos. On s’y remet ?',
  ];

  for (final (largeur, texte) in const [
    (390.0, 1.0),
    (360.0, 1.0),
    (320.0, 1.0),
    (360.0, 1.15),
    (320.0, 1.15),
    (360.0, 1.3),
    (375.0, 1.3),
    (320.0, 1.3),
    (360.0, 1.5),
    (390.0, 2.0),
    (320.0, 2.0),
  ]) {
    testWidgets('à $largeur points, texte ×$texte : chaque phrase d’état '
        'tient ENTIÈRE dans l’en-tête, la citation dans sa bande', (
      tester,
    ) async {
      setPhone(tester, width: largeur, textScale: texte);
      for (final phrase in phrases) {
        await tester.pumpWidget(accueil(subtitle: phrase));
        await tester.pump();

        // Aucune exception de débordement (le harnais les rend fatales), la
        // phrase d'état finit AU-DESSUS de la citation, et rien n'en est
        // coupé : à 320 points en ×2, « Ton corps encaisse encore la
        // dernière séance. » perdait sa fin sous une ellipse.
        final etat = tester.getRect(find.text(phrase));
        final entete = tester.getRect(find.byType(HomeHeader));
        expect(etat.bottom, lessThanOrEqualTo(entete.bottom + 0.5));
        expect(
          truncatedTexts(find.byType(HomeHeader)),
          isNot(contains(phrase)),
        );
        // À la taille d'origine, chaque phrase tient dans les deux lignes
        // réservées : la zone haute a la même hauteur tous les jours.
        if (texte == 1.0) {
          expect(
            tester.getSize(find.byType(HomeHeader)).height,
            HomeHeader.heightFor(TextScaler.noScaling),
            reason: '« $phrase »',
          );
        }
      }
    });
  }

  for (final (largeur, texte) in const [(320.0, 1.0), (320.0, 2.0)]) {
    testWidgets('à $largeur points, texte ×$texte : un prénom long passe à la '
        'ligne plutôt que sous une ellipse, et la citation reste dessous', (
      tester,
    ) async {
      // « Bonjour, Maximilien-… » : la salutation tenait sur UNE ligne, et
      // perdait le prénom sous des points de suspension.
      setPhone(tester, width: largeur, textScale: texte);
      await tester.pumpWidget(
        accueil(displayName: 'Maximilien-Alexandre Durand'),
      );
      await tester.pump();

      final salutation = find.text('Bonjour, Maximilien-Alexandre.');
      expect(truncatedTexts(find.byType(HomeHeader)), isEmpty);
      expect(midWordBreaks(salutation), isEmpty);
      final entete = tester.getRect(find.byType(HomeHeader));
      expect(tester.getRect(salutation).bottom, lessThan(entete.bottom));
      // L'en-tête grandit de la ligne gagnée : la citation part dessous.
      expect(
        tester.getRect(find.byType(DailyQuoteCard)).top,
        greaterThanOrEqualTo(entete.bottom),
      );
    });
  }

  test('à la taille d’origine, l’en-tête garde sa hauteur de maquette', () {
    expect(HomeHeader.heightFor(TextScaler.noScaling), 89);
    expect(
      HomeHeader.heightFor(const TextScaler.linear(1.3)),
      greaterThan(HomeHeader.heightFor(TextScaler.noScaling)),
    );
  });

  testWidgets('le bouton du profil ne dit que « Profil de Maximilien », et la '
      'salutation est un titre', (tester) async {
    final semantics = tester.ensureSemantics();
    setPhone(tester, width: 390);
    await tester.pumpWidget(accueil());
    await tester.pump();

    final profil = tester.getSemantics(
      find.bySemanticsLabel('Profil de Maximilien'),
    );
    expect(profil.label, 'Profil de Maximilien');
    expect(profil.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final salutation = tester.getSemantics(find.text('Bonjour, Maximilien.'));
    expect(salutation.getSemanticsData().flagsCollection.isHeader, isTrue);
    expect(
      salutation.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
    expect(salutation.label, isNot(contains('Profil')));
    expect(salutation.label, isNot(contains('tempo')));
    semantics.dispose();
  });
}
