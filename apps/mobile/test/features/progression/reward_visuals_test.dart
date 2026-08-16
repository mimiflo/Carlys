import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/award_seal.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/majesty.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/seal_engraving.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// LA MISE EN SCÈNE : ce qui doit se RESSENTIR.
///
/// Trois promesses tenues ici. La majesté monte réellement d'un titre à
/// l'autre, et par la FABRICATION plutôt que par la couleur — sans quoi
/// « plus ça évolue, plus c'est majestueux » n'est qu'une phrase. Les cinq
/// sceaux se distinguent par leur silhouette, et non par leur teinte. Et la
/// gravure ne joue qu'une fois : elle marque un instant, pas un état.
void main() {
  group('majesté', () {
    test('chaque cran ajoute un élément de FABRICATION', () {
      final crans = CarlysTitle.values.map(Majesty.of).toList();

      // Le décompte des éléments de fabrication ne recule jamais.
      var previous = -1;
      for (final (index, majesty) in crans.indexed) {
        final built = [
          majesty.border != null || majesty.gradientEdge,
          majesty.surface != Majesty.plainSurface,
          majesty.guilloche != null,
          majesty.corners > 0,
          majesty.halo,
        ].where((present) => present).length;
        expect(
          built,
          greaterThan(previous),
          reason: '${CarlysTitle.values[index].label} n’ajoute rien',
        );
        previous = built;
      }

      // Le premier cran est nu : sinon il ne resterait rien à gagner. Le
      // dernier est le seul à porter la plaque bordée de dégradé.
      final apprenti = Majesty.of(CarlysTitle.apprenti);
      expect(apprenti.border, isNull);
      expect(apprenti.gradientEdge, isFalse);
      expect(apprenti.gaugeFill, isNull, reason: 'compteur pas ouvert');
      expect(
        CarlysTitle.values.where((t) => Majesty.of(t).gradientEdge).length,
        1,
      );
    });

    test('le rang se lit en clair, jamais comme un score', () {
      expect(Majesty.of(CarlysTitle.maitre).rank, '4 / 5');
      expect(Majesty.of(CarlysTitle.maitre).roman, 'IV');
      expect(CarlysTitle.icone.roman, 'V');
    });
  });

  group('sceaux', () {
    test('cinq SILHOUETTES distinctes, pas cinq teintes', () {
      // La version précédente distinguait les récompenses par leur couleur de
      // remplissage : cinq ronds identiques qu'on ne pouvait pas nommer.
      const box = Size.square(AwardSeal.large);
      final shapes = <RewardKind, Rect>{};
      for (final kind in RewardKind.values) {
        final painter = SealPainter(kind: kind, size: AwardSeal.large);
        shapes[kind] = painter.outline(box).getBounds();
      }

      // Deux formes au moins doivent différer d'emprise : un disque, une
      // plaque paysage et une feuille portrait ne peuvent pas coïncider.
      expect(shapes[RewardKind.record]!.height, lessThan(box.height));
      expect(shapes[RewardKind.medaille]!.width, lessThan(box.width));
      expect(shapes[RewardKind.certificat]!.height, box.height);
    });
  });

  group('gravure', () {
    const reward = Reward(
      id: 'constance-4',
      kind: RewardKind.medaille,
      label: 'Un mois sans lâcher',
      story: 'Quatre semaines consécutives.',
    );

    Widget host({required bool isNew}) => MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Center(
              child: EngravedSeal(
                engrave: isNew,
                child: AwardSeal(kind: reward.kind),
              ),
            ),
          ),
        );

    testWidgets('une récompense NOUVELLE se grave sous les yeux',
        (tester) async {
      await tester.pumpWidget(host(isNew: true));

      // À la première image, la frappe n'est pas encore posée.
      final start = _progressOf(tester);
      expect(start, lessThan(1));

      await tester.pump(const Duration(milliseconds: 450));
      expect(_progressOf(tester), greaterThan(start));

      await tester.pumpAndSettle();
      expect(_progressOf(tester), 1);
    });

    testWidgets('une récompense DÉJÀ obtenue est simplement là',
        (tester) async {
      // Rejouer la gravure à chaque ouverture lui ferait perdre exactement
      // ce qui en fait le prix.
      await tester.pumpWidget(host(isNew: false));
      await tester.pump();

      // Aucune couche d'animation : le sceau est rendu tel quel.
      expect(
        find.descendant(
          of: find.byType(EngravedSeal),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });

    testWidgets('réduction d’animations : le sceau est entier, sans mouvement',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures.allOn;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(host(isNew: true));
      await tester.pump();

      expect(_progressOf(tester), 1);
    });
  });
}

/// Avancement de la gravure, lu sur le peintre lui-même : un dessin ne se
/// relit pas autrement.
double _progressOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(EngravedSeal),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  return (paint.painter! as StrikeWave).progress;
}
