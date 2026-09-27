import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/domain/academy_progress.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/academy_domain_header.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/academy_progress_card.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/seal_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enlarged_text.dart';

/// L'ACADEMY SUR UN PETIT ÉCRAN, et en texte agrandi.
///
/// Sur 320 points, en taille de texte NORMALE, la rangée des six sceaux
/// débordait de 14 points (six fois 34 + 8 = 252 pour 238), et la ligne du
/// niveau de 91 (« encore 8 leçons avant Profondeur », non flexible, après
/// un `Spacer`). Dès ×1,5 sur 360 points, le compteur « x / y · z % » des
/// en-têtes de domaine sortait de l'écran.
void main() {
  setUpAll(loadAppFonts);

  Widget monte(Widget enfant) => MaterialApp(
    theme: AppTheme.dark(),
    home: AppDarkScaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [enfant],
      ),
    ),
  );

  AcademyProgress progression(int abordees) => AcademyProgress(
    abordees: abordees,
    total: 38,
    parDomaine: {
      for (final domaine in AcademyCategory.values)
        domaine: const DomainProgress(abordees: 7, total: 12),
    },
  );

  const configurations = [
    (390.0, 1.0),
    (320.0, 1.0),
    (360.0, 1.5),
    (320.0, 2.0),
  ];

  for (final (largeur, texte) in configurations) {
    testWidgets('à $largeur points, texte ×$texte : la carte « Où tu en '
        'es » tient, sceaux compris', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      for (final abordees in [1, 10, 12]) {
        await tester.pumpWidget(
          monte(AcademyProgressCard(progress: progression(abordees))),
        );
        final carte = find.byType(AcademyProgressCard);
        expect(midWordBreaks(carte), isEmpty, reason: '$abordees leçons');
      }
    });

    testWidgets('à $largeur points, texte ×$texte : chaque en-tête de '
        'domaine garde son compteur dans l’écran', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      for (final domaine in AcademyCategory.values) {
        await tester.pumpWidget(
          monte(
            AcademyDomainHeader(
              category: domaine,
              progress: const DomainProgress(abordees: 7, total: 12),
            ),
          ),
        );
        final entete = find.byType(AcademyDomainHeader);
        expect(midWordBreaks(entete), isEmpty, reason: domaine.label);
      }
    });
  }

  testWidgets('à 390 points, les sceaux gardent leur écart de maquette', (
    tester,
  ) async {
    setPhone(tester, width: 390);
    await tester.pumpWidget(
      monte(AcademyProgressCard(progress: progression(12))),
    );
    // Deux sceaux à venir consécutifs (seul le premier est gagné à douze
    // leçons) : leurs centres sont à un sceau plus un écart l'un de l'autre.
    final icones = find.descendant(
      of: find.byType(AcademyProgressCard),
      matching: find.byIcon(AppIcons.record),
    );
    final premier = tester.getCenter(icones.at(0));
    final second = tester.getCenter(icones.at(1));
    expect(
      second.dx - premier.dx,
      closeTo(SealSize.small + AppSpacing.xs, 0.01),
    );
  });
}
