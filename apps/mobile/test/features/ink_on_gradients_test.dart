import 'dart:io';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/domain_completed_banner.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/today_workout_card.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_prefs.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_word.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_bandeau.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/domain/reward_engine.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/reward_controllers.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/title_crossing_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contrast.dart';
import '../support/contrast_table.dart';
import '../support/dart_source.dart';

/// TOUT CE QUI S'ÉCRIT SUR UN DÉGRADÉ COLORÉ SE LIT.
///
/// Les bandeaux de l'application — célébrations au dégradé de marque,
/// Mentor au violet — posent du blanc sur un fond qui change de couleur
/// d'un bord à l'autre. L'audit de septembre 2026 y a trouvé des surtitres
/// à 80 % d'opacité tombés à 3,18:1, et une explication à 2,25:1 sur
/// l'orange de la signature. Deux gardes les empêchent de revenir :
///
/// 1. chaque bandeau est POSÉ, et tout ce qu'il écrit est mesuré contre
///    chaque arrêt de son dégradé (`inkFailuresOn`) ;
/// 2. un balai de source refuse, dans tout fichier qui peint un dégradé
///    coloré, un style de texte en blanc translucide, et refuse la signature
///    d'origine dans tout fichier qui écrit un texte ;
/// 3. un autre refuse, hors du design system, tout ce qui pose un voile
///    d'état SUR une boîte peinte au violet `cta` (ou l'un de ses arrêts)
///    sans dire lequel : un bouton stylé à la main, un `ButtonStyle`, un
///    `InkWell` sur un `Material` au-dessus du dégradé. La recette du bouton
///    a vécu en quatre copies écrites à la main, toutes sans voile — Material
///    le dérivait du blanc du libellé, qui tombait sous 4,5:1 au focus et à
///    l'appui ; le disque « play » de l'accueil, un `InkWell`, prenait les
///    voiles gris clairs du thème sous son icône blanche. La recette ne vit
///    plus que dans le design system (`AppButton`, `AppCtaButton`), où
///    `contrast_pairs_test.dart` mesure chaque état ; un `InkWell` sur le
///    dégradé prend `AppButton.stateOverlay`.
void main() {
  group('chaque bandeau se lit sur tout son dégradé', () {
    testWidgets('domaine bouclé', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: DomainCompletedBanner(
              domaine: AcademyCategory.mobilite,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bandeau = surfacePainting(AppColors.signatureInk);
      expect(bandeau, findsOneWidget);
      expect(inkFailuresOn(tester, bandeau), isEmpty);
    });

    testWidgets('titre franchi, avec son explication', (tester) async {
      final titre = CarlysTitle.architecte;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            earnedRewardsProvider.overrideWith(
              (ref) async => [
                EarnedReward(
                  reward: Reward(
                    id: '$titleRewardPrefix${titre.name}',
                    kind: RewardKind.titre,
                    label: titre.label,
                    story: 'Deux cents points de progression.',
                  ),
                  earnedAt: DateTime.utc(2026, 9, 24),
                  isNew: true,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: TitleCrossingBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bandeau = surfacePainting(AppColors.signatureInk);
      expect(bandeau, findsOneWidget);
      // L'explication est bien là : c'est elle qui descendait sur l'orange.
      expect(find.byIcon(AppIcons.info), findsOneWidget);
      expect(inkFailuresOn(tester, bandeau), isEmpty);
    });

    for (final (nom, mot) in [
      ('sans mot', null),
      ('avec son mot', const MentorWord(message: 'Regarde ta semaine.')),
    ]) {
      testWidgets('Mentor, $nom', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: MentorBandeau(
                mot: mot,
                frequence: MentorFrequency.hebdomadaire,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bandeau = surfacePainting(AppColors.cta);
        expect(bandeau, findsOneWidget);
        expect(inkFailuresOn(tester, bandeau), isEmpty);
      });
    }
  });

  // Le disque « play » de l'accueil : une icône blanche sur le violet, sous
  // un `InkWell` posé à la main. Sans voile à lui, il prenait les voiles
  // gris clairs du thème, et l'appui pâlissait le disque sous l'icône.
  group('le disque « play » de l’accueil, au repos et à chaque état', () {
    mesurerLaTable([
      for (final MapEntry(key: theme, value: construire)
          in themesMesures.entries)
        Ligne('thème $theme : l’icône blanche sur les DEUX bords du dégradé', (
          tester,
        ) async {
          await poser(
            tester,
            TodayWorkoutCard(
              activeWorkout: null,
              onStart: () async {},
              onOpenTemplates: () {},
            ),
            theme: construire,
          );
          final icone = find.byIcon(AppIcons.play);
          final degrade = degradeSous(tester, icone);
          final (:voiles, :eclaboussure) = voilesDeLEncre(
            tester,
            find.ancestor(of: icone, matching: find.byType(InkWell)).first,
          );
          return [
            for (final (bord, fond) in [
              ('bord gauche', degrade.colors.first),
              ('bord droit', degrade.colors.last),
            ])
              ...etatsSur(
                'icône, $bord',
                encreDe(tester, icone),
                fond,
                voiles,
                seuil: wcagGraphic,
                eclaboussure: eclaboussure,
              ),
          ];
        }),
    ]);
  });

  group('le balai des dégradés colorés', () {
    test('aucun texte en blanc translucide sur un dégradé coloré', () {
      final fautes = <String>[];
      for (final fichier in _sources()) {
        final code = dartCode(File(fichier).readAsStringSync());
        if (!_degradeColore.hasMatch(code)) continue;
        for (final faute in _texteTranslucide.allMatches(code)) {
          final ligne =
              '\n'.allMatches(code.substring(0, faute.start)).length + 1;
          fautes.add('$fichier:$ligne');
        }
      }
      expect(
        fautes,
        isEmpty,
        reason:
            'Sur un dégradé coloré, un texte blanc à 80 % tombe sous 4,5:1 : '
            'écrire en `AppColors.neutral0` plein, et porter la hiérarchie '
            'par la taille et la graisse :\n${fautes.join('\n')}',
      );
    });

    test('la signature d’origine ne passe jamais sous un texte', () {
      final fautes = <String>[];
      for (final fichier in _sources()) {
        final code = dartCode(File(fichier).readAsStringSync());
        if (_signatureDOrigine.hasMatch(code) && code.contains('Text(')) {
          fautes.add(fichier);
        }
      }
      expect(
        fautes,
        isEmpty,
        reason:
            'Aucun libellé ne tient AA sur `AppColors.signature` (2,59:1 '
            'sur son orange) : sous un texte, c’est `signatureInk`.\n'
            '${fautes.join('\n')}',
      );
    });

    test('rien ne pose un voile d’état clair sur le violet cta', () {
      final fautes = <String>[
        for (final fichier in _sources())
          if (!fichier.startsWith('lib/design_system/'))
            for (final ligne in _voilesSurCta(
              dartCode(File(fichier).readAsStringSync()),
            ))
              '$fichier:$ligne',
      ];
      expect(
        fautes,
        isEmpty,
        reason:
            'Un bouton ou un `InkWell` posé sur `AppColors.cta` sans '
            '`overlayColor` prend un voile d’état CLAIR, qui pâlit le violet '
            'sous l’encre blanche : employer `AppCtaButton` (ou `AppButton`), '
            'ou donner `overlayColor: AppButton.stateOverlay` à '
            'l’`InkWell`.\n${fautes.join('\n')}',
      );
    });

    test('les motifs reconnaissent ce qu’ils doivent, et rien de plus', () {
      expect(
        _texteTranslucide.hasMatch(
          'style: AppTypography.label.copyWith(\n'
          '  color: AppColors.neutral0.withValues(alpha: 0.8),\n',
        ),
        isTrue,
      );
      // Un VOILE translucide sous une icône n'est pas un texte.
      expect(
        _texteTranslucide.hasMatch(
          'decoration: BoxDecoration(\n'
          '  color: AppColors.neutral0.withValues(alpha: 0.16),\n',
        ),
        isFalse,
      );
      expect(_signatureDOrigine.hasMatch('AppColors.signature,'), isTrue);
      expect(_signatureDOrigine.hasMatch('AppColors.signatureInk,'), isFalse);
      expect(_signatureDOrigine.hasMatch('AppColors.signatureMid'), isFalse);
      expect(_peintureCta.hasMatch('gradient: AppColors.cta,'), isTrue);
      expect(_peintureCta.hasMatch('AppColors.ctaStart'), isTrue);
      expect(_peintureCta.hasMatch('color: AppColors.ctaEnd,'), isTrue);
      expect(_peintureCta.hasMatch('AppColors.ctaMid'), isFalse);
      for (final appel in [
        'FilledButton.styleFrom(',
        'ElevatedButton.styleFrom(',
        'TextButton.styleFrom(',
        'ButtonStyle(',
        'InkWell(',
      ]) {
        expect(_boutonALaMain.hasMatch(appel), isTrue, reason: appel);
      }
    });

    test('le voile se juge SUR la boîte violette, là où il se peint', () {
      // Le disque « play » de l'accueil : un InkWell sur un Material
      // transparent, au-dessus du dégradé.
      const disque =
          'DecoratedBox(decoration: BoxDecoration(gradient: AppColors.cta),\n'
          '  child: Material(color: Colors.transparent,\n'
          '    child: InkWell(onTap: f, child: icone)))';
      expect(_voilesSurCta(disque), [3]);
      expect(
        _voilesSurCta(
          disque.replaceFirst('onTap', 'overlayColor: AppButton.x, onTap'),
        ),
        isEmpty,
      );
      // Un Material peint en violet porte lui-même l'encre.
      expect(
        _voilesSurCta(
          'Material(color: AppColors.ctaEnd, child: InkWell(onTap: f))',
        ),
        [1],
      );
      // Un bouton, un style écrit à la main : chacun a son Material.
      for (final bouton in [
        'FilledButton(style: FilledButton.styleFrom(elevation: 0))',
        'TextButton(style: TextButton.styleFrom(), child: t)',
        'FilledButton(style: ButtonStyle(elevation: e), child: t)',
      ]) {
        expect(
          _voilesSurCta(
            'Container(decoration: BoxDecoration(gradient: '
            'LinearGradient(colors: [AppColors.ctaStart, AppColors.ctaEnd])), '
            'child: $bouton)',
          ),
          [1],
          reason: bouton,
        );
      }
      // Un InkWell SANS Material au-dessus du dégradé peint son encre SOUS
      // la boîte (le bandeau de l'objectif) : rien à voiler.
      expect(
        _voilesSurCta(
          'Container(decoration: BoxDecoration(gradient: AppColors.cta),\n'
          '  child: Column(children: [InkWell(onTap: f, child: pastille)]))',
        ),
        isEmpty,
      );
      // Un InkWell VOISIN de la boîte violette ne se pose pas dessus.
      expect(
        _voilesSurCta(
          'Row(children: [Container(color: AppColors.ctaEnd),\n'
          '  InkWell(onTap: f)])',
        ),
        isEmpty,
      );
    });
  });
}

/// Un fichier qui peint l'un des dégradés colorés de l'application.
final _degradeColore = RegExp(
  r'AppColors\.(cta|signature|signatureInk|violetRamp|energy)\b',
);

/// Un style de TEXTE (le `copyWith` d'un style) teint en blanc translucide.
final _texteTranslucide = RegExp(
  r'\.copyWith\(\s*color:\s*AppColors\.neutral0\.withValues\(',
);

/// La signature d'origine, pas sa variante sous un texte ni ses arrêts
/// (`\b` s'arrête au nom exact).
final _signatureDOrigine = RegExp(r'AppColors\.signature\b');

/// Le violet `cta` ou l'un de ses arrêts.
final _peintureCta = RegExp(r'AppColors\.cta(?:Start|End)?\b');

/// Ce qui pose un voile d'état : un bouton stylé à la main, un style écrit
/// en entier, une encre.
final _boutonALaMain = RegExp(
  r'\b(?:(?:Filled|Elevated|Text|Outlined)Button\.styleFrom|ButtonStyle'
  r'|InkWell|InkResponse)\(',
);

/// Ce qui peint une boîte, et ce qui ne fait que la décrire en chemin.
final _boites = {'DecoratedBox', 'Container', 'AnimatedContainer', 'Ink'};
const _encres = {'Material', 'Ink'};
final _descriptions = RegExp(
  r'^(?:BoxDecoration|ShapeDecoration|(?:Linear|Radial|Sweep)Gradient)$',
);

/// Les lignes où un voile d'état se pose sur une boîte peinte au violet
/// `cta` sans `overlayColor`. Un bouton a son propre `Material` : son voile
/// se peint sur le violet. Un `InkWell`, lui, peint sur le `Material` le
/// plus proche au-dessus de lui : sous la boîte (masqué par elle), sauf
/// si un `Material` s'intercale entre la boîte et lui — ou si c'est un
/// `Material` qui peint le violet.
Set<int> _voilesSurCta(String code) {
  final lignes = <int>{};
  for (final peinture in _peintureCta.allMatches(code)) {
    final boite = _boiteQuiPeint(code, peinture.start);
    if (boite == null) continue;
    final (nom, ouverture) = boite;
    final fermeture = closingEnd(code, ouverture);
    final dedans = code.substring(ouverture, fermeture);
    for (final voile in _boutonALaMain.allMatches(dedans)) {
      final encre = voile.group(0)!.startsWith('Ink');
      final avant = dedans.substring(0, voile.start);
      if (encre &&
          !_encres.contains(nom) &&
          !RegExp(r'\b(?:Material|Ink)\(').hasMatch(avant)) {
        continue;
      }
      final debut = ouverture + voile.end - 1;
      if (code
          .substring(debut, closingEnd(code, debut))
          .contains('overlayColor')) {
        continue;
      }
      lignes.add('\n'.allMatches(code.substring(0, debut)).length + 1);
    }
  }
  return lignes;
}

/// L'appel qui PEINT ce qui est nommé à [position] — la boîte dont la
/// décoration, ou le `Material` dont la couleur, le porte —, avec la
/// position de sa parenthèse ouvrante. `null` si le nom sert à autre chose.
(String, int)? _boiteQuiPeint(String code, int position) {
  var depuis = position;
  while (true) {
    final ouverture = enclosingOpen(code, depuis);
    if (ouverture == null || code[ouverture] == '{') return null;
    if (code[ouverture] == '(') {
      final nom = RegExp(
        r'([A-Za-z_][A-Za-z0-9_]*)\s*$',
      ).firstMatch(code.substring(0, ouverture))?.group(1);
      if (nom == null) return null;
      if (_boites.contains(nom) || _encres.contains(nom)) {
        return (nom, ouverture);
      }
      if (!_descriptions.hasMatch(nom)) return null;
    }
    depuis = ouverture;
  }
}

/// Tout le code de l'application, design system compris.
Iterable<String> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .map((file) => file.path)
    .where((path) => path.endsWith('.dart') && !path.endsWith('.g.dart'));
