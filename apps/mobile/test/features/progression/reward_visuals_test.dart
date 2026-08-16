import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/reward_medal.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/title_regalia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// LA MISE EN SCÈNE : ce qui doit se RESSENTIR.
///
/// Deux promesses tenues ici. La majesté monte réellement d'un titre à
/// l'autre — sans quoi « plus ça évolue, plus c'est majestueux » n'est
/// qu'une phrase. Et la gravure ne joue qu'une fois : elle marque un
/// instant, pas un état.
void main() {
  group('majesté', () {
    test('chaque palier ajoute quelque chose de VISIBLE', () {
      final regalias = CarlysTitle.values.map(TitleRegalia.of).toList();

      // Le liseré ne recule jamais, et le halo non plus.
      for (var i = 1; i < regalias.length; i++) {
        expect(
          regalias[i].borderWidth,
          greaterThanOrEqualTo(regalias[i - 1].borderWidth),
          reason: CarlysTitle.values[i].label,
        );
        expect(
          regalias[i].glow,
          greaterThanOrEqualTo(regalias[i - 1].glow),
          reason: CarlysTitle.values[i].label,
        );
      }

      // Le premier palier ne brille pas : sinon il ne resterait rien à
      // gagner. Le dernier est le seul couronné.
      expect(TitleRegalia.of(CarlysTitle.apprenti).glow, 0);
      expect(TitleRegalia.of(CarlysTitle.apprenti).crowned, isFalse);
      expect(TitleRegalia.of(CarlysTitle.icone).crowned, isTrue);
      expect(
        CarlysTitle.values.where((t) => TitleRegalia.of(t).crowned).length,
        1,
      );
    });

    test('le halo passe par une OMBRE, jamais par un fond', () {
      // Posé en fond, il grisaillerait la carte au lieu de la faire rayonner.
      final decoration = TitleRegalia.of(CarlysTitle.icone).decoration;

      expect(decoration.boxShadow, isNotNull);
      expect(decoration.color, AppColors.darkSurface);
    });
  });

  group('gravure', () {
    const reward = Reward(
      id: 'constance-4',
      kind: RewardKind.medaille,
      label: 'Un mois sans lâcher',
      story: 'Quatre semaines consécutives.',
    );

    Widget host(Widget child) => MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: Center(child: child)),
        );

    testWidgets('une récompense NOUVELLE se grave sous les yeux',
        (tester) async {
      await tester.pumpWidget(
        host(const RewardMedal(reward: reward, isNew: true)),
      );

      // À la première image, le sceau n'est pas encore fermé.
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
      await tester.pumpWidget(host(const RewardMedal(reward: reward)));
      await tester.pump();

      expect(_progressOf(tester), 1);
    });

    testWidgets('réduction d’animations : le sceau est entier, sans mouvement',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures.allOn;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        host(const RewardMedal(reward: reward, isNew: true)),
      );
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
          of: find.byType(RewardMedal),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  return (paint.painter! as MedalPainter).progress;
}
