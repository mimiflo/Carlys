import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_media_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/contrast.dart';
import '../../support/fake_exercises_repository.dart';

/// LE VOILE DE LA FICHE D'UN EXERCICE se fond dans le fond de l'écran.
///
/// Peint en `darkBackground` en dur, il finissait en #08050E sur une page
/// que le réglage « Sombre OLED » peint en noir : une bande nette sous la
/// photo, en travers de la fiche. Il prend désormais le fond de la page.
void main() {
  for (final (nom, construire, attendu) in [
    ('OLED', AppTheme.oledDark, AppColors.oledBackground),
    ('sombre', AppTheme.dark, AppColors.darkBackground),
  ]) {
    testWidgets('sous le thème $nom, le bas du voile est ${hex(attendu)}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: construire(),
          home: Scaffold(
            body: ExerciseMediaHeader(
              exercise: detailOf(summary('id-1', 'Squat', group: 'quadri')),
            ),
          ),
        ),
      );
      // Le voile descend du haut vers le bas ; le fond du repli, lui, part
      // du coin haut gauche.
      final voile = [
        for (final element
            in find
                .descendant(
                  of: find.byType(ExerciseMediaHeader),
                  matching: find.byType(DecoratedBox),
                )
                .evaluate())
          if (((element.widget as DecoratedBox).decoration as BoxDecoration)
                  .gradient
              case final LinearGradient g when g.begin == Alignment.topCenter)
            g,
      ].single;
      expect(voile.colors.last, attendu);
      for (final couleur in voile.colors) {
        expect(hex(couleur.withValues(alpha: 1)), hex(attendu));
      }
    });
  }
}
