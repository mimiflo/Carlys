import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contrast.dart';
import '../support/contrast_table.dart';

/// LA TABLE DES CONTRASTES DU DESIGN SYSTEM.
///
/// Chaque ligne pose un composant dans un état et LIT ce qu'il peint : la
/// couleur résolue du texte, le dégradé ou l'aplat dessous, le voile d'état,
/// le thème. Puis elle mesure chaque paire contre son seuil WCAG 2.2 AA :
/// 4,5:1 pour un texte de taille normale, 3:1 pour une icône. Rien n'est
/// recopié : si un composant change de couleur, c'est la nouvelle qui est
/// mesurée.
///
/// Un dégradé se mesure à ses ARRÊTS — ses deux bords pour le bouton
/// principal —, jamais à sa moyenne, et le voile d'un état est celui que le
/// bouton PEINT : la mécanique est dans `support/contrast_table.dart`. Ce
/// qui se pose sur les surfaces peintes en sombre sous TOUS les réglages
/// (écran, feuille, barre en verre) a sa table à part :
/// `dark_surfaces_test.dart`.
///
/// Hors table, et c'est voulu : le bouton principal EN CHARGEMENT. Il est
/// désactivé, et l'ensemble — dégradé et indicateur — pâlit d'un même
/// mouvement ; un composant inactif est exempté par WCAG (1.4.3 et 1.4.11).
/// L'appel à l'action ([AppCtaButton]), lui, pose son indicateur sur une
/// plaque qui ne pâlit pas : il est mesuré.
void main() => mesurerLaTable(_table);

final _table = <Ligne>[
  for (final MapEntry(key: theme, value: construire)
      in themesMesures.entries) ...[
    Ligne(
      'AppButton principal, thème $theme : le libellé sur les DEUX bords du '
      'dégradé, au repos et à chaque état',
      (tester) async {
        await poser(
          tester,
          AppButton(label: 'Valider', onPressed: () {}),
          theme: construire,
        );
        final bouton = find.byType(FilledButton);
        final degrade = degradeSous(tester, bouton);
        return [
          for (final (bord, fond) in [
            ('bord gauche', degrade.colors.first),
            ('bord droit', degrade.colors.last),
          ])
            ...etatsSur(
              '« Valider », $bord',
              encreDe(tester, find.text('Valider')),
              fond,
              voilesDe(tester, bouton),
            ),
        ];
      },
    ),
    // Sans fond à eux, le contour et le fantôme se posent sur la page ou
    // sur une carte, que leur voile d'état teinte de violet — ici celles du
    // thème AMBIANT, celles des écrans qui le suivent. Sur une surface
    // peinte en sombre sous tous les réglages : `dark_surfaces_test.dart`.
    for (final variante in [AppButtonVariant.secondary, AppButtonVariant.ghost])
      Ligne(
        'AppButton ${variante.name}, thème $theme : le libellé sur la page et '
        'sur une carte, au repos et à chaque état',
        (tester) async {
          await poser(
            tester,
            AppButton(label: 'Annuler', variant: variante, onPressed: () {}),
            theme: construire,
          );
          final bouton = find.byWidgetPredicate((w) => w is ButtonStyleButton);
          final contexte = Theme.of(tester.element(bouton));
          return [
            for (final (sur, dessous) in [
              ('la page', contexte.scaffoldBackgroundColor),
              ('une carte', contexte.colorScheme.surface),
            ])
              ...etatsSur(
                '« Annuler » sur $sur',
                encreDe(tester, find.text('Annuler')),
                over(materielDe(tester, bouton), dessous),
                voilesDe(tester, bouton),
              ),
          ];
        },
      ),
    Ligne(
      'AppCtaButton, thème $theme : le libellé et l’icône sur les DEUX bords '
      'du dégradé, au repos et à chaque état',
      (tester) async {
        await poser(
          tester,
          AppCtaButton(
            label: 'Valider la série',
            icon: AppIcons.check,
            onPressed: () {},
          ),
          theme: construire,
        );
        final bouton = find.byType(FilledButton);
        final degrade = degradeSous(tester, bouton);
        return [
          for (final (bord, fond) in [
            ('bord gauche', degrade.colors.first),
            ('bord droit', degrade.colors.last),
          ]) ...[
            ...etatsSur(
              '« Valider la série », $bord',
              encreDe(tester, find.text('Valider la série')),
              fond,
              voilesDe(tester, bouton),
            ),
            ...etatsSur(
              'icône, $bord',
              encreDe(tester, find.byIcon(AppIcons.check)),
              fond,
              voilesDe(tester, bouton),
              seuil: wcagGraphic,
            ),
          ],
        ];
      },
    ),
    Ligne(
      'AppCtaButton en chargement, thème $theme : l’indicateur sur la plaque '
      'RÉELLEMENT peinte dessous',
      (tester) async {
        await poser(
          tester,
          AppCtaButton(
            label: 'Enregistrer',
            icon: AppIcons.check,
            isLoading: true,
            onPressed: () {},
          ),
          theme: construire,
          enBoucle: true,
        );
        final bouton = find.byType(FilledButton);
        final plaque = voileSous(tester, bouton);
        final page = Theme.of(tester.element(bouton)).scaffoldBackgroundColor;
        return [
          (
            quoi: 'indicateur sur la plaque ${hex(plaque)}',
            encre: tester
                .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator),
                )
                .color!,
            fond: over(materielDe(tester, bouton), over(plaque, page)),
            seuil: wcagGraphic,
          ),
        ];
      },
    ),
    for (final (variante, libelle) in [
      (AppButtonVariant.destructive, 'Supprimer'),
      (AppButtonVariant.accent, 'Choisir'),
    ])
      Ligne(
        'AppButton ${variante.name}, thème $theme : le libellé sur son aplat, '
        'au repos et à chaque état',
        (tester) async {
          await poser(
            tester,
            AppButton(label: libelle, variant: variante, onPressed: () {}),
            theme: construire,
          );
          final bouton = find.byType(FilledButton);
          return etatsSur(
            '« $libelle »',
            encreDe(tester, find.text(libelle)),
            materielDe(tester, bouton),
            voilesDe(tester, bouton),
          );
        },
      ),
    for (final variante in [
      AppButtonVariant.secondary,
      AppButtonVariant.ghost,
      AppButtonVariant.destructive,
      AppButtonVariant.accent,
    ])
      Ligne('AppButton ${variante.name} en chargement, thème $theme : '
          'l’indicateur sur ce qui est RÉELLEMENT peint dessous', (
        tester,
      ) async {
        await poser(
          tester,
          AppButton(
            label: 'Valider',
            variant: variante,
            isLoading: true,
            onPressed: () {},
          ),
          theme: construire,
          enBoucle: true,
        );
        final indicateur = tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color!;
        // Désactivé, le bouton n'a plus son fond : transparent pour le
        // contour et le texte, un voile gris pour les pleins. Il se pose
        // sur la page ou sur une carte.
        final bouton = find.byWidgetPredicate((w) => w is ButtonStyleButton);
        final peint = materielDe(tester, bouton);
        final contexte = Theme.of(tester.element(bouton));
        return [
          for (final (sur, dessous) in [
            ('la page', contexte.scaffoldBackgroundColor),
            ('une carte', contexte.colorScheme.surface),
          ])
            (
              quoi: 'indicateur sur ${variante.name}, posé sur $sur',
              encre: indicateur,
              fond: over(peint, dessous),
              seuil: wcagGraphic,
            ),
        ];
      }),
    for (final variante in AppBadgeVariant.values)
      Ligne('AppBadge ${variante.name}, thème $theme : le libellé sur sa '
          'pastille, posée sur la page, une carte ou la surface alternée', (
        tester,
      ) async {
        await poser(
          tester,
          AppBadge(label: 'Terminée', variant: variante),
          theme: construire,
        );
        final pastille =
            (tester
                        .widget<Container>(
                          find
                              .descendant(
                                of: find.byType(AppBadge),
                                matching: find.byType(Container),
                              )
                              .first,
                        )
                        .decoration!
                    as BoxDecoration)
                .color!;
        final contexte = Theme.of(tester.element(find.byType(AppBadge)));
        return [
          for (final (sur, dessous) in [
            ('la page', contexte.scaffoldBackgroundColor),
            ('une carte', contexte.colorScheme.surface),
            (
              'la surface alternée',
              contexte.colorScheme.surfaceContainerHighest,
            ),
          ])
            (
              quoi: '« Terminée » sur $sur',
              encre: encreDe(tester, find.text('Terminée')),
              fond: over(pastille, dessous),
              seuil: wcagText,
            ),
        ];
      }),
  ],
  for (final (nom, degrade) in [
    ('par défaut (page de bienvenue)', null),
    ('cta (connexion, inscription)', AppColors.cta),
  ])
    Ligne('AppBrandButton $nom : le libellé blanc sur chaque arrêt du dégradé, '
        'au repos et sous le doigt', (tester) async {
      await poser(
        tester,
        degrade == null
            ? AppBrandButton(label: 'Commencer', onPressed: () {})
            : AppBrandButton(
                label: 'Commencer',
                gradient: degrade,
                onPressed: () {},
              ),
      );
      final libelle = find.text('COMMENCER');
      final encre = encreDe(tester, libelle);
      final arrets = stopsOf(degradeSous(tester, libelle));
      final paires = <Paire>[
        for (final arret in arrets)
          (
            quoi: 'au repos, sur ${hex(arret)}',
            encre: encre,
            fond: arret,
            seuil: wcagText,
          ),
      ];
      final doigt = await tester.startGesture(tester.getCenter(libelle));
      await tester.pump(kPressTimeout);
      await tester.pumpAndSettle();
      final voile = voileSous(tester, libelle);
      paires.addAll([
        for (final arret in arrets)
          (
            quoi: 'sous le doigt, sur ${hex(arret)}',
            encre: encreDe(tester, libelle),
            fond: over(voile, arret),
            seuil: wcagText,
          ),
      ]);
      await doigt.up();
      await tester.pumpAndSettle();
      return paires;
    }),
  Ligne('AppBottomBar : libellés et icônes, actifs et inactifs, sur la barre '
      'translucide au-dessus de tout ce qui peut passer dessous', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          bottomNavigationBar: AppBottomBar(currentIndex: 0, onTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final verre = tester
        .widget<AppTranslucentBar>(find.byType(AppTranslucentBar))
        .color!;
    const dessous = {
      'le fond sombre': AppColors.darkBackground,
      'une carte': AppColors.darkSurface,
      'une plaque gravée': AppColors.surfaceIcon,
      'une page claire': AppColors.lightBackground,
      'une photo blanche': AppColors.neutral0,
    };
    return [
      for (final item in appBottomBarItems)
        for (final MapEntry(key: sur, value: fond) in dessous.entries) ...[
          (
            quoi: '« ${item.label} » au-dessus de $sur',
            encre: encreDe(tester, find.text(item.label)),
            fond: over(verre, fond),
            seuil: wcagText,
          ),
          (
            quoi: 'icône de « ${item.label} » au-dessus de $sur',
            encre: _iconeDe(tester, item.label),
            fond: over(verre, fond),
            seuil: wcagGraphic,
          ),
        ],
    ];
  }),
  Ligne('AppSegmentedTabs sur 320 points : l’onglet choisi sur chaque arrêt de '
      'sa pastille, les autres sur la piste, le compte sur son accent', (
    tester,
  ) async {
    await poser(
      tester,
      SizedBox(
        width: 320,
        child: AppSegmentedTabs(
          segments: const [
            AppSegment('Défis'),
            AppSegment('Ligue'),
            AppSegment('Amis', count: 2),
          ],
          selectedIndex: 1,
          onSelected: (_) {},
        ),
      ),
    );
    final piste =
        (tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(AppSegmentedTabs),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration)
            .color!;
    return [
      for (final arret in stopsOf(degradeSous(tester, find.text('Ligue'))))
        (
          quoi: '« Ligue » (choisi) sur ${hex(arret)}',
          encre: encreDe(tester, find.text('Ligue')),
          fond: arret,
          seuil: wcagText,
        ),
      for (final autre in ['Défis', 'Amis'])
        (
          quoi: '« $autre » sur la piste',
          encre: encreDe(tester, find.text(autre)),
          fond: piste,
          seuil: wcagText,
        ),
      (
        quoi: 'le compte « 2 » sur son accent',
        encre: encreDe(tester, find.text('2')),
        fond: AppColors.accent,
        seuil: wcagText,
      ),
    ];
  }),
  for (final mise in [false, true])
    Ligne('AppInitialAvatar ${mise ? 'mis en avant' : 'des autres'} : '
        'l’initiale sur chaque couleur de son disque', (tester) async {
      await poser(
        tester,
        AppInitialAvatar(name: 'Wanda', size: 36, highlighted: mise),
      );
      final disque =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(AppInitialAvatar),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      return [
        for (final fond in disque.gradient?.colors ?? [disque.color!])
          (
            quoi: '« W » sur ${hex(fond)}',
            encre: encreDe(tester, find.text('W')),
            fond: fond,
            seuil: wcagText,
          ),
      ];
    }),
];

/// L'icône de l'onglet dont le libellé est [libelle].
Color _iconeDe(WidgetTester tester, String libelle) => tester
    .widget<Icon>(
      find.descendant(
        of: find
            .ancestor(of: find.text(libelle), matching: find.byType(Column))
            .first,
        matching: find.byType(Icon),
      ),
    )
    .color!;
