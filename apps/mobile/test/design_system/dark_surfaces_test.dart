import 'dart:async';
import 'dart:io';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/design_system/scenes/app_scene_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contrast.dart';
import '../support/contrast_table.dart';
import '../support/dart_source.dart';

/// CE QUI EST PEINT EN SOMBRE SE LIT DANS LE THÈME.
///
/// L'application n'a que deux thèmes, tous deux sombres : « Sombre » et
/// « Sombre OLED », qui promet un fond NOIR PUR. Trois gardes :
///
/// 1. la page (`Scaffold`) et les voiles des scènes prennent le fond du
///    thème, jamais `darkBackground` en dur ;
/// 2. la table mesure, dans chaque thème, ce qui se pose sur chaque surface
///    sombre, contre ce que la surface PEINT ;
/// 3. un balai refuse un `Scaffold` ou une barre d'application peints en
///    sombre à la main hors du design system.
void main() {
  group('la page (Scaffold)', () {
    // Le réglage « Sombre OLED » promet un fond NOIR PUR. L'écran sombre
    // peignait pourtant `darkBackground` en dur : 42 écrans sur 44 gardaient
    // #08050E sous l'OLED, seule la barre d'application passait au noir.
    for (final (nom, construire, attendu) in [
      ('OLED', AppTheme.oledDark, AppColors.oledBackground),
      ('sombre', AppTheme.dark, AppColors.darkBackground),
    ]) {
      testWidgets('sous le thème $nom, il peint ${hex(attendu)}', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: construire(),
            home: Scaffold(
              appBar: AppBar(title: const Text('Titre')),
              body: const SizedBox(),
            ),
          ),
        );
        expect(_fondDeLaPage(tester), attendu);
        // La barre d'application prend le MÊME fond : pas de couture.
        final barre = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(barre.color, attendu);
      });
    }
  });

  group('ce qui se FOND dans la page en prend le fond', () {
    // Les voiles des scènes (hero de l'accueil, de Nutrition, de
    // l'abonnement) finissent sur le fond de la page, pour que la scène s'y
    // éteigne. Peints en `darkBackground` en dur, ils dessinaient sous
    // l'OLED, où la page est noire, une bande #08050E / #000000 au bas du
    // hero : la couture de la barre d'application, déplacée plus bas.
    for (final (nom, construire, attendu) in [
      ('OLED', AppTheme.oledDark, AppColors.oledBackground),
      ('sombre', AppTheme.dark, AppColors.darkBackground),
    ]) {
      testWidgets('sous le thème $nom, les voiles des scènes finissent sur '
          '${hex(attendu)}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: construire(),
            home: const Scaffold(
              body: Column(
                children: [
                  SizedBox(height: 100, child: AppSceneScrim.lateral()),
                  SizedBox(height: 100, child: AppSceneScrim.vertical()),
                ],
              ),
            ),
          ),
        );
        final voiles = [
          for (final element
              in find
                  .descendant(
                    of: find.byType(AppSceneScrim),
                    matching: find.byType(DecoratedBox),
                  )
                  .evaluate())
            ((element.widget as DecoratedBox).decoration as BoxDecoration)
                    .gradient!
                as LinearGradient,
        ];
        expect(voiles, hasLength(2));
        for (final voile in voiles) {
          // Le point opaque est le fond de la page ; les points voilés en
          // sont des transparences, jamais une autre encre.
          expect(voile.colors.where((c) => c.a == 1), [attendu]);
          for (final couleur in voile.colors.where((c) => c.a > 0)) {
            expect(hex(couleur.withValues(alpha: 1)), hex(attendu));
          }
        }
      });
    }
  });

  group('ce qui se pose sur une surface sombre, dans chaque thème', () {
    mesurerLaTable(_table);
  });

  test('aucun écran ne peint son Scaffold en sombre à la main', () {
    final fautes = <String>[
      for (final fichier in _sources())
        if (!fichier.startsWith('lib/design_system/'))
          for (final ligne in _scaffoldsSombres(
            dartCode(File(fichier).readAsStringSync()),
          ))
            '$fichier:$ligne',
    ];
    expect(
      fautes,
      isEmpty,
      reason:
          'Un `Scaffold` peint en `darkBackground` reste #08050E sous '
          '« Sombre OLED », qui promet un fond noir : laisser le fond au '
          'thème.\n${fautes.join('\n')}',
    );
  });

  test('aucune barre d’application ne peint le fond sombre à la main', () {
    // Posée sur la page, une barre peinte en `darkBackground`
    // dessinait une couture sous l'OLED, où la page est noire : le thème
    // donne déjà à la barre le fond de la page.
    final fautes = <String>[
      for (final fichier in _sources())
        if (!fichier.startsWith('lib/design_system/'))
          for (final ligne in _barresSombres(
            dartCode(File(fichier).readAsStringSync()),
          ))
            '$fichier:$ligne',
    ];
    expect(fautes, isEmpty, reason: fautes.join('\n'));
    expect(
      _barresSombres('AppBar(backgroundColor: AppColors.darkBackground)'),
      [1],
    );
    expect(_barresSombres('AppBar(title: x)'), isEmpty);
  });

  test('le balai reconnaît un Scaffold sombre, et rien de plus', () {
    expect(
      _scaffoldsSombres(
        'return Scaffold(\n'
        '  backgroundColor: AppColors.darkBackground,\n'
        '  body: x,\n'
        ');',
      ),
      [1],
    );
    // Une barre d'application peinte en sombre DANS un Scaffold ordinaire
    // n'est pas le fond de l'écran.
    expect(
      _scaffoldsSombres(
        'Scaffold(appBar: AppBar(backgroundColor: AppColors.darkBackground))',
      ),
      isEmpty,
    );
    expect(_scaffoldsSombres('Scaffold(body: x)'), isEmpty);
  });
}

/// Une surface peinte en sombre sous tous les réglages : ce qu'elle pose
/// sous un composant, et les fonds OPAQUES qu'elle peint dessous.
class _Surface {
  const _Surface(this.nom, this.poser);

  final String nom;
  final Future<List<Color>> Function(
    WidgetTester tester,
    Widget composant,
    ThemeData Function() theme, {
    required bool enBoucle,
  })
  poser;
}

final _surfaces = <_Surface>[
  _Surface('sur un écran sombre', (
    tester,
    composant,
    theme, {
    required enBoucle,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme(),
        home: Scaffold(body: Center(child: composant)),
      ),
    );
    await attendre(tester, enBoucle: enBoucle);
    return [_fondDeLaPage(tester)];
  }),
  for (final style in AppSheetStyle.values)
    _Surface('dans une feuille ${style.name}', (
      tester,
      composant,
      theme, {
      required enBoucle,
    }) async {
      await tester.pumpWidget(
        MaterialApp(theme: theme(), home: const Scaffold()),
      );
      unawaited(
        showAppSheet<void>(
          tester.element(find.byType(Scaffold)),
          style: style,
          builder: (_) => Center(child: composant),
        ),
      );
      await attendre(tester, enBoucle: enBoucle);
      return [
        tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor!,
      ];
    }),
  // Le verre translucide se compose sur ce qui défile dessous — la page
  // sombre, une carte, une photo blanche.
  _Surface('dans une barre en verre', (
    tester,
    composant,
    theme, {
    required enBoucle,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme(),
        home: Scaffold(
          bottomNavigationBar: AppTranslucentBar(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: composant,
            ),
          ),
        ),
      ),
    );
    await attendre(tester, enBoucle: enBoucle);
    final verre =
        (tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(AppTranslucentBar),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration)
            .color!;
    return [
      for (final dessous in [
        AppColors.darkBackground,
        AppColors.darkSurface,
        AppColors.neutral0,
      ])
        over(verre, dessous),
    ];
  }),
];

final _table = <Ligne>[
  for (final MapEntry(key: theme, value: construire) in themesMesures.entries)
    for (final surface in _surfaces) ...[
      for (final variante in [
        AppButtonVariant.secondary,
        AppButtonVariant.ghost,
      ])
        Ligne('AppButton ${variante.name} ${surface.nom}, thème $theme : le '
            'libellé sur ce que la surface peint, au repos et à chaque état', (
          tester,
        ) async {
          final fonds = await surface.poser(
            tester,
            AppButton(label: 'Annuler', variant: variante, onPressed: () {}),
            construire,
            enBoucle: false,
          );
          final bouton = find.byWidgetPredicate((w) => w is ButtonStyleButton);
          return [
            for (final fond in fonds)
              ...etatsSur(
                '« Annuler » sur ${hex(fond)}',
                encreDe(tester, find.text('Annuler')),
                over(materielDe(tester, bouton), fond),
                voilesDe(tester, bouton),
              ),
          ];
        }),
      Ligne('AppCtaButton en chargement ${surface.nom}, thème $theme : '
          'l’indicateur sur la plaque RÉELLEMENT peinte dessous', (
        tester,
      ) async {
        final fonds = await surface.poser(
          tester,
          AppCtaButton(
            label: 'Enregistrer',
            icon: AppIcons.check,
            isLoading: true,
            onPressed: () {},
          ),
          construire,
          enBoucle: true,
        );
        final bouton = find.byType(FilledButton);
        final plaque = voileSous(tester, bouton);
        return [
          for (final fond in fonds)
            (
              quoi:
                  'indicateur sur la plaque ${hex(plaque)}, '
                  'sur ${hex(fond)}',
              encre: tester
                  .widget<CircularProgressIndicator>(
                    find.byType(CircularProgressIndicator),
                  )
                  .color!,
              fond: over(materielDe(tester, bouton), over(plaque, fond)),
              seuil: wcagGraphic,
            ),
        ];
      }),
    ],
];

/// Ce que le `Scaffold` PEINT : son `Material`, au fond du thème.
Color _fondDeLaPage(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(Scaffold),
            matching: find.byType(Material),
          )
          .first,
    )
    .color!;

/// Les lignes des `Scaffold` dont un argument DIRECT les peint en sombre.
List<int> _scaffoldsSombres(String code) => [
  for (final appel in RegExp(r'\bScaffold\(').allMatches(code))
    if (_argumentDirect(
      code,
      appel.end - 1,
      RegExp(
        r'backgroundColor:\s*AppColors\.(?:darkBackground|oledBackground)',
      ),
    ))
      '\n'.allMatches(code.substring(0, appel.start)).length + 1,
];

/// Les lignes des `AppBar` dont un argument DIRECT les peint en sombre.
List<int> _barresSombres(String code) => [
  for (final appel in RegExp(r'\bAppBar\(').allMatches(code))
    if (_argumentDirect(
      code,
      appel.end - 1,
      RegExp(r'backgroundColor:\s*AppColors\.darkBackground'),
    ))
      '\n'.allMatches(code.substring(0, appel.start)).length + 1,
];

/// Vrai si [motif] se trouve au premier niveau des arguments ouverts à
/// [ouverture], pas dans un appel imbriqué.
bool _argumentDirect(String code, int ouverture, RegExp motif) {
  final fin = closingEnd(code, ouverture);
  for (final trouve in motif.allMatches(code.substring(ouverture, fin))) {
    if (enclosingOpen(code, ouverture + trouve.start) == ouverture) {
      return true;
    }
  }
  return false;
}

/// Tout le code de l'application.
Iterable<String> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .map((file) => file.path)
    .where((path) => path.endsWith('.dart') && !path.endsWith('.g.dart'));
