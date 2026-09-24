import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le COMPORTEMENT de l'appel à l'action ; ses contrastes, état par état,
/// sont dans `contrast_pairs_test.dart`.
Widget _poser(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: Center(child: child)),
);

/// La boîte peinte sous le bouton : dégradé actif, plaque désactivé.
BoxDecoration _fond(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .ancestor(
                    of: find.byType(FilledButton),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  testWidgets('actif : le dégradé cta, son halo, et le geste au doigt', (
    tester,
  ) async {
    var pressions = 0;
    await tester.pumpWidget(
      _poser(
        AppCtaButton(
          label: 'Lancer',
          icon: AppIcons.play,
          onPressed: () => pressions++,
        ),
      ),
    );

    expect(_fond(tester).gradient, AppColors.cta);
    expect(_fond(tester).boxShadow, isNotEmpty);
    expect(find.byIcon(AppIcons.play), findsOneWidget);

    await tester.tap(find.text('Lancer'));
    expect(pressions, 1);
  });

  testWidgets('sans halo quand on le lui demande (barre basse)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _poser(
        AppCtaButton(
          label: 'Ajouter à la séance',
          icon: AppIcons.add,
          glow: false,
          height: 54,
          onPressed: () {},
        ),
      ),
    );

    expect(_fond(tester).boxShadow, isNull);
    expect(tester.getSize(find.byType(FilledButton)).height, 54);
  });

  testWidgets('désactivé : la plaque de la surface, sans halo ni geste', (
    tester,
  ) async {
    await tester.pumpWidget(
      _poser(
        const AppCtaButton(
          label: 'Enregistrer',
          icon: AppIcons.check,
          onPressed: null,
        ),
      ),
    );

    expect(_fond(tester).gradient, isNull);
    expect(_fond(tester).color, AppColors.darkSurface);
    expect(_fond(tester).boxShadow, isNull);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('en chargement : désactivé, indicateur annoncé, un seul envoi', (
    tester,
  ) async {
    var pressions = 0;
    await tester.pumpWidget(
      _poser(
        AppCtaButton(
          label: 'Enregistrer',
          icon: AppIcons.check,
          isLoading: true,
          loadingLabel: 'Enregistrement',
          onPressed: () => pressions++,
        ),
      ),
    );

    expect(find.text('Enregistrer'), findsNothing);
    expect(find.bySemanticsLabel('Enregistrement'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton));
    expect(pressions, 0);
  });

  // Dans une barre en verre (l'éditeur de modèle), le bouton se pose sur un
  // fond sombre sous TOUS les réglages. Sous le thème clair, il posait une
  // plaque BLANCHE et un indicateur au violet vif sur la barre sombre :
  // la barre lui impose le thème sombre, et il y paraît comme en sombre.
  for (final (nom, theme) in [
    ('sombre', AppTheme.dark),
    ('clair', AppTheme.light),
    ('OLED', AppTheme.oledDark),
  ]) {
    testWidgets('thème $nom, dans une barre en verre : la plaque sombre et '
        'l’indicateur violet clair', (tester) async {
      Future<void> poserDansLaBarre({required bool enChargement}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme(),
            home: Scaffold(
              bottomNavigationBar: AppTranslucentBar(
                child: AppCtaButton(
                  label: 'Enregistrer',
                  icon: AppIcons.check,
                  isLoading: enChargement,
                  onPressed: enChargement ? () {} : null,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await poserDansLaBarre(enChargement: false);
      expect(_fond(tester).color, AppColors.darkSurface);

      await poserDansLaBarre(enChargement: true);
      expect(_fond(tester).color, AppColors.darkSurface);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        AppColors.primaryLight,
      );
    });
  }

  testWidgets('le lecteur d’écran entend le libellé qu’on lui destine', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _poser(
        AppCtaButton(
          label: 'Lancer',
          icon: AppIcons.play,
          semanticLabel: 'Lancer le modèle Push force',
          onPressed: () {},
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('Lancer le modèle Push force')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
