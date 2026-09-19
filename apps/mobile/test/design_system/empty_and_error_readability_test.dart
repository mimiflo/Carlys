import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : deux états lus par toute l'application restent
/// lisibles quel que soit le thème choisi.
///
/// Les écrans peignent leur fond en `AppColors.darkBackground` — l'application
/// est sombre par dessin, quarante-cinq fichiers le font. Ces deux composants,
/// eux, prenaient leurs couleurs de `Theme.of(context)`, dont l'`onSurface`
/// vaut `neutral900` sous le thème Clair : titre et message s'écrivaient en
/// quasi-noir sur ce fond sombre. « Aucun événement », « Communauté
/// indisponible » — invisibles, pile au moment où l'écran n'a que ça à dire.
void main() {
  /// La couleur RÉELLEMENT peinte pour ce texte, thème Clair appliqué.
  Color? couleurSousThemeClair(WidgetTester tester, String texte) =>
      tester.widget<Text>(find.text(texte)).style?.color;

  Future<void> monter(WidgetTester tester, Widget composant) {
    return tester.pumpWidget(
      MaterialApp(
        // Le thème CLAIR, celui sous lequel le défaut se voyait.
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: composant,
        ),
      ),
    );
  }

  testWidgets('AppEmptyState reste clair sur fond sombre', (tester) async {
    await monter(
      tester,
      const AppEmptyState(
        title: 'Personne ici pour l’instant',
        message: 'Ajoute un ami pour commencer.',
      ),
    );

    expect(
      couleurSousThemeClair(tester, 'Personne ici pour l’instant'),
      AppColors.darkTextPrimary,
    );
    expect(
      couleurSousThemeClair(tester, 'Ajoute un ami pour commencer.'),
      AppColors.darkTextSecondary,
    );
  });

  testWidgets('AppErrorState reste clair sur fond sombre', (tester) async {
    await monter(
      tester,
      const AppErrorState(
        title: 'Communauté indisponible',
        message: AppErrorState.retryConnectionMessage,
      ),
    );

    expect(
      couleurSousThemeClair(tester, 'Communauté indisponible'),
      AppColors.darkTextPrimary,
    );
    expect(
      couleurSousThemeClair(tester, AppErrorState.retryConnectionMessage),
      AppColors.darkTextSecondary,
    );
  });
}
