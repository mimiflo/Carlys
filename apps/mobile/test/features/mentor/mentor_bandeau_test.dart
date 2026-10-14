import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_prefs.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_word.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_bandeau.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_celebration_bandeau.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enlarged_text.dart';

/// Le bandeau du Mentor : un mot ordinaire garde sa robe, une célébration
/// prend la sienne (médaille, « Un nouveau cap ») — et aucun des deux ne
/// déborde sur un petit écran au texte agrandi.
void main() {
  setUpAll(loadAppFonts);

  Widget monte(MentorWord mot) => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            MentorBandeau(
              mot: mot,
              frequence: MentorFrequency.hebdomadaire,
              voix: 'Bienveillant',
            ),
          ],
        ),
      ),
    ),
  );

  const celebration = MentorWord(
    message:
        '« Cinq leçons abordées », c’est à toi. Prends deux secondes '
        'pour le savourer.',
    celebratedRewardId: 'maitrise-5',
  );
  const ordinaire = MentorWord(
    message: 'Regarde ta semaine, pas ta journée : c’est elle qui progresse.',
  );

  testWidgets('une célébration prend la robe de la célébration', (
    tester,
  ) async {
    await tester.pumpWidget(monte(celebration));
    expect(find.byType(MentorCelebrationBandeau), findsOneWidget);
    expect(find.text('UN NOUVEAU CAP'), findsOneWidget);
    expect(find.text('Une nouvelle récompense est à toi.'), findsOneWidget);
    expect(find.text(celebration.message), findsOneWidget);
  });

  testWidgets('un mot ordinaire garde la sienne', (tester) async {
    await tester.pumpWidget(monte(ordinaire));
    expect(find.byType(MentorCelebrationBandeau), findsNothing);
    expect(find.text('LE MOT DE LA SEMAINE'), findsOneWidget);
  });

  for (final (largeur, texte) in const [(320.0, 1.3), (320.0, 2.0)]) {
    testWidgets('$largeur points, texte ×$texte : aucun débordement', (
      tester,
    ) async {
      setPhone(tester, width: largeur, textScale: texte);
      for (final mot in const [celebration, ordinaire]) {
        await tester.pumpWidget(monte(mot));
        expect(tester.takeException(), isNull, reason: mot.message);
        expect(
          midWordBreaks(find.byType(MentorBandeau)),
          isEmpty,
          reason: mot.message,
        );
      }
    });
  }
}
