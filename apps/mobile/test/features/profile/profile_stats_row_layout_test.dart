import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/dashboard/domain/entities/consistency_week.dart';
import 'package:carlys_mobile/features/dashboard/presentation/providers/home_day_providers.dart';
import 'package:carlys_mobile/features/profile/presentation/providers/profile_hub_providers.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enlarged_text.dart';

/// LES TROIS CHIFFRES DU PROFIL, en texte agrandi.
///
/// Trois colonnes sur la largeur d'un téléphone : dès ×1,3 sur 360 points,
/// « jours consécutifs » se coupait en son milieu (« consécutif / s »).
void main() {
  setUpAll(loadAppFonts);

  Widget monte() => ProviderScope(
    overrides: [
      consistencyWeekProvider.overrideWith(
        (ref) => const ConsistencyWeek(days: [], streakDays: 12),
      ),
      profileSessionsCountProvider.overrideWith((ref) => const AsyncData(148)),
      profileFriendsCountProvider.overrideWith((ref) => const AsyncData(7)),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: const [ProfileStatsRow()],
        ),
      ),
    ),
  );

  for (final (largeur, texte) in const [
    (390.0, 1.0),
    (320.0, 1.0),
    (360.0, 1.3),
    (360.0, 1.5),
    (320.0, 2.0),
  ]) {
    testWidgets('à $largeur points, texte ×$texte : aucun libellé ne se coupe '
        'dans un mot', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      await tester.pumpWidget(monte());

      final rangee = find.byType(ProfileStatsRow);
      expect(midWordBreaks(rangee), isEmpty);
      expect(find.text('jours consécutifs'), findsOneWidget);
    });
  }
}
