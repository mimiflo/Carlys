import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texte qui se dimensionne pour remplir sa boîte.
///
/// Le besoin : la citation du jour reçoit toujours le même cadre alors que
/// les maximes vont du simple au double en longueur. Sans ajustement, le
/// cadre paraîtrait creux un jour et déborderait le lendemain.
void main() {
  const box = Size(200, 160);

  Future<double> sizeOf(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: AppFittedText(
                text,
                minFontSize: 12,
                maxFontSize: 40,
                style: const TextStyle(height: 1.3),
              ),
            ),
          ),
        ),
      ),
    );
    return tester.widget<Text>(find.text(text)).style!.fontSize!;
  }

  testWidgets('une phrase courte prend un plus grand corps qu’une longue', (
    tester,
  ) async {
    final short = await sizeOf(tester, 'Le tempo est une charge invisible.');
    final long = await sizeOf(
      tester,
      'Maîtriser, c’est pouvoir s’arrêter à n’importe quel moment du geste, '
      'et cette phrase est délibérément très longue pour le vérifier.',
    );

    expect(short, greaterThan(long));
  });

  testWidgets('le texte ne dépasse jamais la boîte reçue', (tester) async {
    for (final text in [
      'Court.',
      'Une maxime de longueur moyenne, comme la plupart du recueil.',
      'Une maxime démesurée, répétée encore et encore, bien au-delà de ce '
          'que le cadre peut contenir au corps maximum, pour forcer la '
          'réduction jusqu’à la borne basse et vérifier qu’il n’y a aucun '
          'débordement possible.',
    ]) {
      await sizeOf(tester, text);
      expect(tester.takeException(), isNull, reason: text);

      final rendered = tester.getSize(find.text(text));
      expect(rendered.height, lessThanOrEqualTo(box.height), reason: text);
      expect(rendered.width, lessThanOrEqualTo(box.width), reason: text);
    }
  });

  testWidgets('les bornes sont respectées', (tester) async {
    final size = await sizeOf(tester, 'x');

    // Une phrase minuscule ne dépasse pas le corps maximal demandé.
    expect(size, lessThanOrEqualTo(40));
    expect(size, greaterThanOrEqualTo(12));
  });

  testWidgets('sans hauteur bornée, le corps maximal est retenu', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 200,
              child: AppFittedText(
                'Rien à remplir ici.',
                minFontSize: 12,
                maxFontSize: 40,
                style: TextStyle(height: 1.3),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Rien à remplir ici.')).style!.fontSize,
      40,
    );
  });

  group('mémoïsation', () {
    setUp(() => AppFittedText.misesEnPage = 0);

    testWidgets('une reconstruction à entrées IDENTIQUES ne recalcule rien', (
      tester,
    ) async {
      // La dichotomie tournait dans le `builder` d'un `LayoutBuilder` : elle
      // se rejouait à chaque image, huit mises en page par tuile, pour un
      // résultat inchangé. Le compteur est le seul moyen de le voir — la
      // mémoïsation n'a, par construction, aucun effet à l'écran.
      final cle = GlobalKey();
      Widget scene() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 40,
            width: 120,
            child: AppFittedText(
              'Développé couché',
              key: cle,
              style: AppTypography.body,
              minFontSize: 8,
              maxFontSize: 24,
            ),
          ),
        ),
      );

      await tester.pumpWidget(scene());
      final premier = AppFittedText.misesEnPage;
      expect(premier, greaterThan(0), reason: 'le premier calcul a bien lieu');

      // Même arbre, mêmes contraintes : rien à recalculer.
      await tester.pumpWidget(scene());
      expect(AppFittedText.misesEnPage, premier);
    });

    testWidgets('changer le TEXTE recalcule', (tester) async {
      // Le risque que la mémoïsation introduit : servir un corps calculé
      // pour un autre texte. C'est ce qui doit être gardé, pas l'économie.
      final cle = GlobalKey();
      Widget scene(String texte) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 40,
            width: 120,
            child: AppFittedText(
              texte,
              key: cle,
              style: AppTypography.body,
              minFontSize: 8,
              maxFontSize: 24,
            ),
          ),
        ),
      );

      await tester.pumpWidget(scene('Court'));
      final court = tester.widget<Text>(find.text('Court')).style?.fontSize;
      final apresPremier = AppFittedText.misesEnPage;

      await tester.pumpWidget(
        scene('Un libellé nettement plus long que le précédent, et alors'),
      );
      expect(AppFittedText.misesEnPage, greaterThan(apresPremier));

      final long = tester
          .widget<Text>(
            find.text(
              'Un libellé nettement plus long que le précédent, et alors',
            ),
          )
          .style
          ?.fontSize;
      expect(long, isNotNull);
      expect(court, isNotNull);
      expect(long! < court!, isTrue, reason: 'le texte long rétrécit');
    });

    testWidgets('changer la BOÎTE recalcule', (tester) async {
      final cle = GlobalKey();
      Widget scene(double hauteur) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: hauteur,
            width: 120,
            child: AppFittedText(
              'Développé couché incliné haltères',
              key: cle,
              style: AppTypography.body,
              minFontSize: 8,
              maxFontSize: 24,
            ),
          ),
        ),
      );

      await tester.pumpWidget(scene(40));
      final apresPremier = AppFittedText.misesEnPage;

      await tester.pumpWidget(scene(18));
      expect(AppFittedText.misesEnPage, greaterThan(apresPremier));
    });
  });
}
