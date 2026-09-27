import 'dart:async';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enlarged_text.dart';

/// LES CHAMPS À LIBELLÉ INTÉGRÉ (connexion, inscription, popups de saisie).
///
/// Le libellé y est à la fois le texte fantôme et la sémantique du champ :
/// le lecteur d'écran l'annonçait donc DEUX fois — « Mot de passe, Mot de
/// passe, champ de texte ». Le texte fantôme qui RÉPÈTE le libellé est
/// désormais muet pour lui ; il se dessine exactement comme avant, jusqu'à
/// son nombre de lignes. Un fantôme DISTINCT du libellé (l'exemple d'une
/// popup de saisie) reste lu : il dit quoi écrire.
void main() {
  group('à 320 points, texte ×2', () {
    setUpAll(loadAppFonts);

    // Material borne le fantôme aux lignes du champ, ellipse comprise. Le
    // fantôme muet l'avait oublié : « Adresse e-mail » passait sur deux
    // lignes, et le champ vide de la connexion de 68 à 112 points — qu'il
    // gardait pendant la saisie.
    for (final (nom, nous) in [
      (
        'AppTextField',
        const AppTextField(
          label: 'Adresse e-mail',
          inlineLabel: true,
          prefixIcon: AppIcons.mail,
        ),
      ),
      (
        'AppPasswordField',
        const AppPasswordField(
          label: 'Adresse e-mail',
          inlineLabel: true,
          prefixIcon: AppIcons.mail,
        ),
      ),
    ]) {
      testWidgets('$nom : le champ vide garde la hauteur de celui de '
          'Material, pendant la saisie aussi', (tester) async {
        setPhone(tester, width: 320, textScale: 2);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  // La largeur d'un champ de popup sur un petit écran.
                  width: 220,
                  child: Column(
                    children: [
                      KeyedSubtree(key: const Key('nous'), child: nous),
                      const TextField(
                        key: Key('material'),
                        decoration: InputDecoration(
                          hintText: 'Adresse e-mail',
                          prefixIcon: Icon(AppIcons.mail),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final material = tester.getSize(find.byKey(const Key('material')));
        expect(tester.getSize(find.byKey(const Key('nous'))), material);

        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('nous')),
            matching: find.byType(TextField),
          ),
          'l',
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(const Key('nous'))), material);
      });
    }

    testWidgets('un champ de trois lignes laisse au fantôme ses trois '
        'lignes, comme Material', (tester) async {
      setPhone(tester, width: 320, textScale: 2);
      const long = 'Ce que tu as ressenti pendant la séance, en quelques mots';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                AppTextField(label: long, inlineLabel: true, maxLines: 3),
              ],
            ),
          ),
        ),
      );
      final fantome = tester.renderObject<RenderParagraph>(find.text(long));
      expect(fantome.maxLines, 3);
      expect(fantome.overflow, TextOverflow.ellipsis);
    });
  });

  testWidgets('popup de saisie : l’exemple distinct du libellé reste lu', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    late BuildContext ecran;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            ecran = context;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showAppPrompt(
        ecran,
        title: 'Activité libre',
        hint: 'Course, vélo, yoga…',
      ),
    );
    await tester.pumpAndSettle();

    // Le libellé nomme le champ ; l'exemple, seul texte visible DANS le
    // champ, dit quoi y écrire — le lecteur d'écran l'entend aussi.
    final champ = tester.getSemantics(find.byType(TextField)).label;
    expect(champ, contains('Activité libre'));
    expect(champ, contains('Course, vélo, yoga…'));
    semantics.dispose();
  });

  for (final (nom, construire) in [
    ('sombre', AppTheme.dark),
    ('OLED', AppTheme.oledDark),
  ]) {
    Widget monte(Widget champ) => MaterialApp(
      theme: construire(),
      home: Scaffold(body: Column(children: [champ])),
    );

    testWidgets('thème $nom : « Adresse e-mail » s’annonce une fois, vide '
        'comme rempli', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        monte(const AppTextField(label: 'Adresse e-mail', inlineLabel: true)),
      );
      expect(
        tester.getSemantics(find.byType(TextField)).label,
        'Adresse e-mail',
      );

      await tester.enterText(find.byType(TextField), 'lea@exemple.fr');
      await tester.pumpAndSettle();
      final rempli = tester.getSemantics(find.byType(TextField));
      expect(rempli.label, 'Adresse e-mail');
      expect(rempli.value, 'lea@exemple.fr');
      semantics.dispose();
    });

    testWidgets('thème $nom : « Mot de passe » s’annonce une fois', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        monte(const AppPasswordField(label: 'Mot de passe', inlineLabel: true)),
      );
      expect(tester.getSemantics(find.byType(TextField)).label, 'Mot de passe');
      semantics.dispose();
    });

    for (final actif in [true, false]) {
      testWidgets('thème $nom, champ ${actif ? 'actif' : 'inactif'} : le '
          'texte fantôme se dessine comme celui de Material', (tester) async {
        await tester.pumpWidget(
          monte(
            Column(
              children: [
                AppTextField(
                  label: 'Nom affiché',
                  inlineLabel: true,
                  enabled: actif,
                ),
                TextField(
                  enabled: actif,
                  decoration: const InputDecoration(hintText: 'Référence'),
                ),
              ],
            ),
          ),
        );
        TextStyle style(String texte) =>
            tester.renderObject<RenderParagraph>(find.text(texte)).text.style!;
        final nous = style('Nom affiché');
        final material = style('Référence');
        expect(nous.color, material.color);
        expect(nous.fontSize, material.fontSize);
        expect(nous.fontFamily, material.fontFamily);
        expect(nous.fontWeight, material.fontWeight);
        expect(nous.height, material.height);
        expect(nous.letterSpacing, material.letterSpacing);
        expect(
          tester.getSize(find.text('Nom affiché')).height,
          tester.getSize(find.text('Référence')).height,
        );
      });
    }
  }
}
