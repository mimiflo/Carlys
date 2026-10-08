import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/widgets/carlys_profile_card.dart';
import 'package:carlys_mobile/features/dashboard/presentation/providers/today_metrics.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/today_grid.dart';
import 'package:carlys_mobile/features/progression/presentation/providers/reward_providers.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/progression_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enlarged_text.dart';

/// DES HAUTEURS FIXES QUI CACHAIENT UNE INFORMATION.
///
/// Trois blocs calculés pour le texte ×1 sur un téléphone moyen :
/// - le bloc de progression de l'accueil (120 points) rognait sa ligne
///   « Dernière : … » dès ×1,3 — devenu la bannière « Mon parcours », il
///   garde la garde : son texte se lit entier ;
/// - les cartes des profils Carlys (132 points) coupaient à l'ellipse les
///   noms et trois descriptions sur quatre à 320 points, alors qu'un
///   commentaire les disait « ENTIÈRES à la largeur d'un téléphone » ;
/// - la tuile Calories de l'accueil tronquait sa cible (« / 2 759 k… ») à
///   320 points comme à 360 en ×1,3.
void main() {
  setUpAll(loadAppFonts);

  Widget monte(Widget enfant, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [enfant],
            ),
          ),
        ),
      );

  for (final (largeur, texte) in const [
    (390.0, 1.0),
    (375.0, 1.3),
    (360.0, 1.5),
    (320.0, 2.0),
  ]) {
    testWidgets('« Mon parcours », $largeur points, texte ×$texte : le texte '
        'se lit entier', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      await tester.pumpWidget(
        monte(
          const ProgressionEntryCard(),
          overrides: [showcaseRewardsProvider.overrideWithValue(const [])],
        ),
      );

      final carte = find.byType(ProgressionEntryCard);
      expect(truncatedTexts(carte), isEmpty);
      expect(midWordBreaks(carte), isEmpty);
    });
  }

  for (final (largeur, texte) in const [
    (390.0, 1.0),
    (320.0, 1.0),
    (375.0, 1.3),
    (320.0, 2.0),
  ]) {
    testWidgets('profils Carlys, $largeur points, texte ×$texte : noms et '
        'descriptions entiers', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      for (final profile in CarlysProfile.values) {
        await tester.pumpWidget(
          monte(
            CarlysProfileCard(
              profile: profile,
              isCurrent: profile == CarlysProfile.challenger,
              onTap: () {},
            ),
          ),
        );
        final carte = find.byType(CarlysProfileCard);
        expect(truncatedTexts(carte), isEmpty, reason: profile.name);
        expect(midWordBreaks(carte), isEmpty, reason: profile.name);
      }
    });
  }

  for (final (largeur, texte) in const [
    (390.0, 1.0),
    (320.0, 1.0),
    (360.0, 1.3),
  ]) {
    testWidgets('tuile Calories, $largeur points, texte ×$texte : la cible '
        'se lit entière', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      TodayMetric mesure(TodayMetricKind kind, String label) => TodayMetric(
        kind: kind,
        label: label,
        value: '1 240',
        target: '/ 2 759 kcal',
        note: 'Il en reste 1 519',
        ratio: 0.45,
      );
      await tester.pumpWidget(
        monte(
          TodayGrid(
            metrics: [
              mesure(TodayMetricKind.calories, 'Calories'),
              mesure(TodayMetricKind.proteines, 'Protéines'),
              mesure(TodayMetricKind.hydratation, 'Eau'),
              mesure(TodayMetricKind.volume, 'Volume'),
            ],
          ),
        ),
      );

      final tronques = truncatedTexts(find.byType(TodayGrid));
      expect(tronques, isNot(contains('/ 2 759 kcal')));
    });
  }
}
