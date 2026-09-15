import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/title_explanations.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/titles_explained_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La feuille qui manquait : l'échelle entière, et le sens de chaque palier.
///
/// L'application affichait « Apprenti » et « 4 / 5 PALIERS » sans qu'aucune
/// surface ne dise ce que ces mots veulent dire.
void main() {
  /// Fenêtre HAUTE : la feuille liste cinq paliers dans un `ListView`
  /// paresseux, et sur 600 points de haut les derniers ne sont pas encore
  /// construits. C'est le défilement qu'on éviterait de tester ici, pas le
  /// contenu — même parti pris que `progression_flow_test`.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
          ..physicalSize = const Size(1200, 3000)
          ..devicePixelRatio = 3;
    addTearDown(view.reset);
  });

  Future<void> ouvrir(
    WidgetTester tester, {
    CarlysTitle porte = CarlysTitle.architecte,
    CarlysTitle grave = CarlysTitle.architecte,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () =>
                    showTitlesExplained(context, porte: porte, grave: grave),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('les CINQ paliers sont là, avec leur seuil', (tester) async {
    await ouvrir(tester);

    for (final titre in CarlysTitle.values) {
      expect(
        find.text(titre.label),
        findsWidgets,
        reason: '« ${titre.label} » manque à l’échelle.',
      );
      expect(
        find.text('${titre.threshold}'),
        findsWidgets,
        reason: 'Le seuil de « ${titre.label} » manque.',
      );
      expect(find.text(titre.roman), findsWidgets);
    }
  });

  testWidgets('un palier ouvre SON explication complète', (tester) async {
    await ouvrir(tester);

    await tester.tap(find.text(CarlysTitle.icone.label).last);
    await tester.pumpAndSettle();

    expect(find.text('Ce que c’est'.toUpperCase()), findsOneWidget);
    expect(find.text('D’où ça sort'.toUpperCase()), findsOneWidget);
    expect(
      find.textContaining('860 points'),
      findsOneWidget,
      reason: 'L’explication d’Icône doit citer son seuil.',
    );
  });

  testWidgets('le mot « rang » a enfin sa définition', (tester) async {
    await ouvrir(tester);

    await tester.tap(find.text(TitleExplanations.rang.titre));
    await tester.pumpAndSettle();

    expect(find.textContaining('chiffre romain'), findsWidgets);
    expect(
      find.textContaining('n’est pas un score'),
      findsOneWidget,
      reason: 'C’est la phrase qui distingue un rang d’un score.',
    );
  });

  testWidgets('quand le titre porté est redescendu, le palier GRAVÉ se voit', (
    tester,
  ) async {
    // Le cas qui rassure, et que rien n'énonçait : les points ont reculé,
    // l'écrin non.
    await ouvrir(
      tester,
      porte: CarlysTitle.architecte,
      grave: CarlysTitle.maitre,
    );

    expect(find.text('GRAVÉ'), findsOneWidget);
  });

  testWidgets('sans écart, aucune mention « GRAVÉ » ne parasite', (
    tester,
  ) async {
    await ouvrir(tester, porte: CarlysTitle.maitre, grave: CarlysTitle.maitre);

    expect(find.text('GRAVÉ'), findsNothing);
  });

  testWidgets('chaque palier dépasse la cible tactile minimale', (
    tester,
  ) async {
    await ouvrir(tester);

    for (final titre in CarlysTitle.values) {
      final ligne = find.ancestor(
        of: find.text(titre.label),
        matching: find.byType(AppExplainable),
      );
      expect(
        tester.getSize(ligne.first).height,
        greaterThanOrEqualTo(AppSpacing.touchTarget),
        reason: 'La ligne « ${titre.label} » est trop courte pour un doigt.',
      );
    }
  });
}
