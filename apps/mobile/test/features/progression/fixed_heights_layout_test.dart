import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/widgets/carlys_profile_card.dart';
import 'package:carlys_mobile/features/dashboard/presentation/controllers/today_metrics.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/today_grid.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/domain/reward_engine.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/progression_controllers.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/reward_controllers.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/progression_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enlarged_text.dart';

/// DES HAUTEURS FIXES QUI CACHAIENT UNE INFORMATION.
///
/// Trois blocs calculés pour le texte ×1 sur un téléphone moyen :
/// - le bloc de progression de l'accueil (120 points) rognait sa ligne
///   « Dernière : … » dès ×1,3 ;
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
          home: AppDarkScaffold(
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [enfant],
            ),
          ),
        ),
      );

  final profil = ProgressionProfile(
    axes: [
      for (final valeur in CarlysValue.values)
        ProgressionAxis(
          value: valeur,
          ratio: 0.5,
          points: 60,
          reason: 'Fixture de test.',
        ),
    ],
  );
  final recompense = EarnedReward(
    reward: rewardCatalog.last.reward,
    earnedAt: DateTime.utc(2026, 9, 1),
  );

  for (final (largeur, texte) in const [
    (390.0, 1.0),
    (375.0, 1.3),
    (360.0, 1.5),
    (320.0, 2.0),
  ]) {
    testWidgets('bloc de progression, $largeur points, texte ×$texte : la '
        'dernière récompense reste dans le bloc', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      await tester.pumpWidget(
        monte(
          const ProgressionEntryCard(),
          overrides: [
            progressionProfileProvider.overrideWithValue(profil),
            highestTitleProvider.overrideWithValue(profil.title),
            showcaseRewardsProvider.overrideWithValue([recompense]),
          ],
        ),
      );

      final bloc = tester.getRect(find.byType(ProgressionEntryCard));
      final derniere = tester.getRect(find.textContaining('Dernière : '));
      expect(bloc.bottom, greaterThanOrEqualTo(derniere.bottom));
      if (texte == 1.0) {
        // À la taille d'origine, la hauteur de maquette.
        expect(bloc.height, ProgressionEntryCard.height);
      }
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
