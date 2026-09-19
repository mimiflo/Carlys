import 'package:carlys_mobile/core/explanations/explanation.dart';
import 'package:carlys_mobile/core/explanations/explanation_sheet.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : le bouton « J'ai compris » reste atteignable.
///
/// La feuille posait ses trois blocs dans une simple colonne. Du texte libre
/// un peu long — et « ce que ça ne dit pas », le bloc le plus utile, est aussi
/// le plus bavard — ou une taille de police système relevée, et le bouton
/// passait sous le bord de l'écran sans que rien ne permette d'aller le
/// chercher.

/// Une explication VOLONTAIREMENT longue, comme les plus denses du catalogue.
final _longue = Explanation(
  titre: 'Dépense énergétique',
  cequeCest: 'Ce que ton corps brûle sur une journée. ' * 12,
  douCaSort: 'Mifflin-St Jeor, puis le facteur de ton niveau d’activité. ' * 12,
  cequeCaNeDitPas: 'C’est une ESTIMATION statistique, pas une mesure. ' * 12,
);

void main() {
  testWidgets('feuille longue : le bouton se rejoint en défilant', (
    tester,
  ) async {
    // Un écran court, celui où le défaut se voyait le plus vite.
    tester.view.physicalSize = const Size(1080, 1400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showExplanation(context, _longue),
              child: const Text('Pourquoi ?'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pourquoi ?'));
    await tester.pumpAndSettle();

    // La feuille est bien ouverte, et elle DÉFILE.
    expect(find.text('Dépense énergétique'), findsOneWidget);
    final bouton = find.text('J’ai compris');
    await tester.scrollUntilVisible(
      bouton,
      200,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(bouton);
    await tester.pumpAndSettle();

    // Atteint, appuyé, et la feuille s'est refermée.
    expect(find.text('Dépense énergétique'), findsNothing);
  });

  testWidgets('feuille courte : elle ne prend pas tout l’écran', (
    tester,
  ) async {
    // Le plafond de hauteur ne doit pas devenir une hauteur imposée : une
    // explication brève reste une feuille, pas une page.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showExplanation(
                context,
                const Explanation(
                  titre: 'IMC',
                  cequeCest: 'Un rapport entre poids et taille.',
                  douCaSort: 'Poids divisé par la taille au carré.',
                ),
              ),
              child: const Text('Pourquoi ?'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pourquoi ?'));
    await tester.pumpAndSettle();

    final hauteurFeuille = tester.getSize(find.text('IMC')).height;
    expect(hauteurFeuille, greaterThan(0));
    // Le bouton est visible SANS défiler.
    expect(
      tester.getBottomRight(find.text('J’ai compris')).dy,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
  });
}
