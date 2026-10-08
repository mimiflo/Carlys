import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/domain/academy_progress.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/academy_domain_header.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/academy_progress_card.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/academy_progress_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enlarged_text.dart';

/// L'ACADEMY SUR UN PETIT ÉCRAN, et en texte agrandi.
///
/// Sur 320 points, en taille de texte NORMALE, la rangée des six sceaux
/// débordait de 14 points (six fois 34 + 8 = 252 pour 238) — des médailles
/// de 36 depuis octobre 2026, la même règle tient, et la ligne du
/// niveau de 91 (« encore 8 leçons avant Profondeur », non flexible, après
/// un `Spacer`). Dès ×1,5 sur 360 points, le compteur « x / y · z % » des
/// en-têtes de domaine sortait de l'écran.
void main() {
  setUpAll(loadAppFonts);

  Widget monte(Widget enfant) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
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
    testWidgets('à $largeur points, texte ×$texte : la carte « Ma '
        'progression » tient, médailles comprises', (tester) async {
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

  testWidgets('à 390 points, les médailles gardent leur écart de maquette', (
    tester,
  ) async {
    setPhone(tester, width: 390);
    await tester.pumpWidget(
      monte(AcademyProgressCard(progress: progression(12))),
    );
    // Leurs centres sont à une médaille plus un écart l'un de l'autre.
    final medailles = find.descendant(
      of: find.byType(AcademyProgressCard),
      matching: find.byType(AppMedal),
    );
    final premier = tester.getCenter(medailles.at(1));
    final second = tester.getCenter(medailles.at(2));
    expect(
      second.dx - premier.dx,
      closeTo(AcademyRewardSeal.size + AppSpacing.sm, 0.01),
    );
  });
}
