import 'package:carlys_mobile/features/dashboard/presentation/widgets/home_brand_mark.dart';
import 'package:carlys_mobile/features/training/presentation/widgets/resume_workout_card.dart';
import 'package:carlys_mobile/shared/widgets/summit_illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les illustrations se DÉCODENT à la taille où on les voit, pas à celle du
/// fichier. Décodées telles quelles, les haltères de « Reprends ta séance »
/// (1 708 × 855) pesaient 5,8 Mio dans le cache d'images pour 214 points de
/// large, le sommet des bannières 3,7 Mio, et le sceau de l'en-tête 0,9 Mio
/// pour 15 points de haut.
void main() {
  /// Monte [child] dans un téléphone de 393 points à 3 pixels par point,
  /// laisse les images se décoder pour de vrai, et rend leurs tailles.
  Future<List<Size>> decoded(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
    return [
      for (final raw in tester.widgetList<RawImage>(find.byType(RawImage)))
        Size(raw.image!.width.toDouble(), raw.image!.height.toDouble()),
    ];
  }

  /// Ce que la boîte de [finder] montre, en pixels physiques.
  Size shown(WidgetTester tester, Finder finder) =>
      tester.getSize(finder) * tester.view.devicePixelRatio;

  testWidgets('les haltères, à la largeur de leur boîte', (tester) async {
    final sizes = await decoded(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: ResumeWorkoutCard(onResume: () {}),
      ),
    );
    final box = shown(tester, find.byType(RawImage));
    expect(sizes.single.width, lessThanOrEqualTo(box.width.ceil()));
    // Jamais moins que ce que la boîte montre : pas de flou.
    expect(sizes.single.width, greaterThanOrEqualTo(box.width.floor()));
  });

  testWidgets('le sommet, à la largeur de sa boîte', (tester) async {
    final sizes = await decoded(
      tester,
      const SizedBox(height: 96, child: SummitIllustration()),
    );
    final box = shown(tester, find.byType(RawImage));
    expect(sizes.single.width, lessThanOrEqualTo(box.width.ceil()));
    expect(sizes.single.width, greaterThanOrEqualTo(box.width.floor()));
  });

  testWidgets('le sceau, à sa hauteur d’en-tête', (tester) async {
    final sizes = await decoded(tester, const Center(child: HomeBrandMark()));
    // Le sceau et son halo : la même image, décodée une fois.
    for (final size in sizes) {
      expect(size.height, HomeBrandMark.height * 3);
    }
  });
}
