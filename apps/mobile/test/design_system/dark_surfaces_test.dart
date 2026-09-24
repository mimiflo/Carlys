import 'dart:async';
import 'dart:io';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contrast.dart';
import '../support/contrast_table.dart';
import '../support/dart_source.dart';

/// CE QUI EST PEINT EN SOMBRE PORTE LE THÈME SOMBRE.
///
/// L'écran, la feuille et la barre en verre sont sombres sous TOUS les
/// réglages, thème Clair compris. Ce qui s'y pose lisait pourtant le thème
/// ambiant : sous le Clair, un bouton contour y prenait le violet profond
/// pensé pour une page claire (3,35:1 sur la page sombre), et l'appel à
/// l'action désactivé de l'éditeur une plaque BLANCHE. Aucune encre violette
/// ne tient 4,5:1 à la fois sur la page claire et sur la page sombre : c'est
/// le thème qui doit dire ce qui est peint. Trois gardes :
///
/// 1. `AppDarkTheme` impose le thème sombre sous le Clair, et ne touche à
///    rien sous un thème sombre ;
/// 2. la table mesure, dans chaque thème, ce qui se pose sur chaque surface
///    sombre, contre ce que la surface PEINT ;
/// 3. un balai refuse un `Scaffold` peint en sombre à la main hors du design
///    system : c'est `AppDarkScaffold`, qui porte le fond ET le thème.
void main() {
  group('AppDarkTheme', () {
    ThemeData? lu;
    Widget sonde() => Builder(
      builder: (context) {
        lu = Theme.of(context);
        return const SizedBox();
      },
    );

    testWidgets('sous le thème clair, il impose le thème sombre', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AppDarkTheme(child: sonde()),
        ),
      );
      expect(lu!.brightness, Brightness.dark);
      expect(lu!.colorScheme.primary, AppDarkTheme.theme.colorScheme.primary);
    });

    testWidgets('sous un thème sombre, il transmet le thème ambiant', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.oledDark(),
          home: AppDarkTheme(child: sonde()),
        ),
      );
      // Le fond OLED reste celui de l'OLED : rien n'est imposé.
      expect(lu!.scaffoldBackgroundColor, AppColors.oledBackground);
    });

    testWidgets('basculer le réglage ne reconstruit pas ce qu’il porte', (
      tester,
    ) async {
      final cle = GlobalKey();
      Widget app(ThemeData theme) => MaterialApp(
        theme: theme,
        home: AppDarkTheme(child: SizedBox(key: cle)),
      );
      await tester.pumpWidget(app(AppTheme.light()));
      final avant = cle.currentContext;
      await tester.pumpWidget(app(AppTheme.dark()));
      await tester.pumpAndSettle();
      expect(cle.currentContext, same(avant));
    });
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
          'Un `Scaffold` peint en `darkBackground` laisse le thème ambiant à '
          'son contenu, clair sous le réglage Clair : employer '
          '`AppDarkScaffold`.\n${fautes.join('\n')}',
    );
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
    expect(_scaffoldsSombres('AppDarkScaffold(body: x)'), isEmpty);
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
        home: AppDarkScaffold(body: Center(child: composant)),
      ),
    );
    await attendre(tester, enBoucle: enBoucle);
    return [tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!];
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
  // La barre en verre se pose sur un écran qui SUIT le thème : elle impose
  // le sien d'elle-même. Son verre translucide se compose sur ce qui défile
  // dessous — la page sombre, une carte, une page claire.
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
        AppColors.lightBackground,
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
