import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/utils/progress_stats.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/progress_tiles.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/records_card.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/volume_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/enlarged_text.dart';
import '../../support/fake_progress_repository.dart';

/// La refonte de l'écran Progrès (maquette d'octobre 2026) : les calculs
/// qui la dessinent, et ce qu'elle devient sur un petit écran.
void main() {
  setUpAll(loadAppFonts);

  group('échelles', () {
    test('le pas du volume est rond et donne environ quatre graduations', () {
      expect(volumeScaleStep(0), 1000);
      expect(volumeScaleStep(3400), 1000);
      // Pile sur un pas : il reste ce pas, sans sauter au suivant.
      expect(volumeScaleStep(4000), 1000);
      expect(volumeScaleStep(12000), 5000);
      expect(volumeScaleStep(900), 250);
    });

    test('l’axe du poids garde un cran au-dessus de la plus haute mesure', () {
      // En flottants, 70,3 / 0,1 vaut 702,999… : sans marge, le cran du
      // haut disparaissait et le dernier point touchait le bord.
      for (final (min, max) in const [
        (70.3, 70.3),
        (84.0, 84.6),
        (89.9, 90.1),
        (100.0, 100.3),
        (82.5, 86.0),
      ]) {
        final axis = weightAxis(min, max);
        expect(axis.maxY, greaterThan(max + axis.step / 2), reason: '$max');
        expect(axis.minY, lessThanOrEqualTo(min + 1e-9), reason: '$min');
      }
      // Toutes les mesures égales : deux graduations distinctes.
      final plat = weightAxis(70.3, 70.3);
      expect(plat.maxY - plat.minY, closeTo(plat.step, 1e-9));
    });

    test('chaque barre se légende selon sa granularité', () {
      final lundi = DateTime(2026, 10, 5);
      expect(bucketLabel(lundi, ProgressBucket.day), 'lun. 5');
      expect(bucketLabel(lundi, ProgressBucket.week), '5 oct.');
      expect(bucketLabel(lundi, ProgressBucket.month), 'oct.');
    });
  });

  Widget monte(Widget enfant) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [AppCard(child: enfant)],
      ),
    ),
  );

  List<ProgressPoint> points(int nombre) => [
    for (var i = 0; i < nombre; i++)
      ProgressPoint(
        bucketStart: DateTime.utc(2026, 1 + i % 12, 1 + i),
        sessionsCount: 1,
        volumeKg: 2800 + 100.0 * i,
      ),
  ];

  for (final (nombre, periode) in const [
    (7, ProgressPeriod.week),
    (8, ProgressPeriod.week),
    (13, ProgressPeriod.year),
  ]) {
    for (final texte in const [1.0, 1.5]) {
      testWidgets('$nombre barres sur 320 points, texte ×$texte : aucun '
          'libellé n’en recouvre un autre', (tester) async {
        setPhone(tester, width: 320, textScale: texte);
        await tester.pumpWidget(
          monte(VolumeBars(points: points(nombre), period: periode)),
        );

        // Les libellés d'une même rangée (l'axe du bas) se comparent deux à
        // deux ; ceux de l'échelle, empilés, ne partagent pas de rangée.
        final rects = [
          for (final element
              in find
                  .descendant(
                    of: find.byType(VolumeBars),
                    matching: find.byType(RichText),
                  )
                  .evaluate())
            (element.renderObject! as RenderBox).localToGlobal(Offset.zero) &
                (element.renderObject! as RenderBox).size,
        ];
        for (final a in rects) {
          for (final b in rects) {
            if (identical(a, b) || (a.center.dy - b.center.dy).abs() > 1) {
              continue;
            }
            expect(a.overlaps(b), isFalse, reason: '$a recouvre $b');
          }
        }
      });
    }
  }

  for (final texte in const [1.0, 1.5, 2.0]) {
    testWidgets('tuiles sur 320 points, texte ×$texte : aucun mot coupé', (
      tester,
    ) async {
      setPhone(tester, width: 320, textScale: texte);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                ProgressTiles(
                  overview: overviewOf(
                    ProgressPeriod.week,
                    setsCount: 152,
                    totalDurationSeconds: 17280,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(midWordBreaks(find.byType(ProgressTiles)), isEmpty);
    });
  }

  testWidgets('un record ouvre la progression de son exercice ; sans '
      'exercice connu, il reste muet', (tester) async {
    final records = [
      PersonalRecordEntry(
        id: 'r-1',
        exerciseId: 'dc',
        exerciseName: 'Développé couché',
        type: PersonalRecordType.maxWeight,
        value: 80,
        achievedAt: DateTime.utc(2026, 10, 1),
      ),
      PersonalRecordEntry(
        id: 'r-2',
        exerciseName: 'Exercice retiré',
        type: PersonalRecordType.maxReps,
        value: 12,
        achievedAt: DateTime.utc(2026, 9, 1),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(body: RecordsCard(records: records)),
            ),
            GoRoute(
              path: AppRoutes.exerciseProgression('dc'),
              builder: (_, __) => const Text('Progression du développé'),
            ),
          ],
        ),
      ),
    );

    // Sans exercice connu, la ligne n'est PAS une porte : aucune encre,
    // aucun chevron qui promettrait une page.
    InkWell? porte(String valeur) => tester
        .widgetList<InkWell>(
          find.ancestor(of: find.text(valeur), matching: find.byType(InkWell)),
        )
        .firstOrNull;
    expect(porte('12 rép.')?.onTap, isNull);
    expect(porte('80 kg')?.onTap, isNotNull);
    expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);

    await tester.tap(find.text('80 kg'));
    await tester.pumpAndSettle();
    expect(find.text('Progression du développé'), findsOneWidget);
  });
}
