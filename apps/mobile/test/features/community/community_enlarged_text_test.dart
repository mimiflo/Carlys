import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/challenge_card.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/encouragement_tile.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/friend_challenge/friend_challenge_facts.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/friend_challenge/friend_challenge_notes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_sample_world.dart';
import '../../support/enlarged_text.dart';

/// LA COMMUNAUTÉ EN TEXTE AGRANDI.
///
/// Un même motif, relevé par l'audit de septembre 2026 : un titre qui
/// s'étire, suivi d'un texte de fin qui ne plie pas. En texte ×2, le titre
/// « Message de Léa » s'écrivait une lettre par ligne, le bouton
/// « Participer » sortait de la carte d'un défi du mois, l'heure d'un
/// encouragement repoussait son menu hors de la carte. Et les quatre faits
/// d'un défi entre amis coupaient leurs libellés en plein mot dès ×1,15
/// (« uniquemen / t »).
void main() {
  setUpAll(loadAppFonts);

  Widget monte(Widget enfant) => MaterialApp(
    theme: AppTheme.dark(),
    home: AppDarkScaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [enfant],
      ),
    ),
  );

  const configurations = [
    (390.0, 1.0),
    (320.0, 1.0),
    (390.0, 1.15),
    (360.0, 1.3),
    (390.0, 2.0),
    (320.0, 2.0),
  ];

  for (final (largeur, texte) in configurations) {
    group('à $largeur points, texte ×$texte', () {
      testWidgets('le mot d’un défi entre amis garde un titre en mots', (
        tester,
      ) async {
        setPhone(tester, width: largeur, textScale: texte);
        final defi = sampleFriendChallenges().firstWhere(
          (d) => d.message != null && d.createdAt != null,
        );
        await tester.pumpWidget(monte(FriendChallengeNotes(challenge: defi)));

        final notes = find.byType(FriendChallengeNotes);
        expect(midWordBreaks(notes), isEmpty);
        final titre = find.text('Message de ${defi.creatorDisplayName}');
        expect(tester.getSize(titre).width, greaterThan(60));
      });

      testWidgets('les faits d’un défi entre amis ne coupent aucun mot', (
        tester,
      ) async {
        setPhone(tester, width: largeur, textScale: texte);
        for (final defi in sampleFriendChallenges()) {
          await tester.pumpWidget(monte(FriendChallengeFacts(challenge: defi)));
          final faits = find.byType(FriendChallengeFacts);
          expect(midWordBreaks(faits), isEmpty, reason: defi.title);
          expect(truncatedTexts(faits), isEmpty, reason: defi.title);
        }
      });

      testWidgets('le bouton d’un défi du mois reste dans sa carte', (
        tester,
      ) async {
        setPhone(tester, width: largeur, textScale: texte);
        for (final defi in sampleChallenges().values) {
          await tester.pumpWidget(
            monte(ChallengeCard(challenge: defi, onToggle: () {})),
          );
          final carte = tester.getRect(find.byType(ChallengeCard));
          final bouton = tester.getRect(find.byType(AppButton));
          expect(
            carte.contains(bouton.bottomRight - const Offset(0.5, 0.5)),
            isTrue,
            reason: defi.title,
          );
          expect(midWordBreaks(find.byType(ChallengeCard)), isEmpty);
        }
      });

      testWidgets('le bouton d’un défi du mois se range à droite de sa ligne', (
        tester,
      ) async {
        // Le `Wrap` qui laisse passer le bouton dessous ne prend que la
        // largeur de ses enfants si rien ne l'étire : à ×1, le bouton se
        // collait alors au compte des participants, au milieu de la carte,
        // au lieu de s'aligner sur le bord droit de la barre.
        setPhone(tester, width: largeur, textScale: texte);
        for (final defi in sampleChallenges().values) {
          await tester.pumpWidget(
            monte(ChallengeCard(challenge: defi, onToggle: () {})),
          );
          final barre = tester.getRect(find.byType(LinearProgressIndicator));
          final bouton = tester.getRect(find.byType(AppButton));
          final compte = tester.getRect(find.textContaining('participants'));
          final memeLigne = (bouton.center.dy - compte.center.dy).abs() < 1;
          if (memeLigne) {
            expect(
              bouton.right,
              moreOrLessEquals(barre.right, epsilon: 0.5),
              reason: defi.title,
            );
          }
        }
      });

      testWidgets('un encouragement garde son menu dans la carte', (
        tester,
      ) async {
        setPhone(tester, width: largeur, textScale: texte);
        for (final mot in sampleEncouragements()) {
          await tester.pumpWidget(
            monte(
              EncouragementTile(
                encouragement: mot,
                onDelete: () {},
                onBlock: () {},
                onReport: () {},
              ),
            ),
          );
          final carte = tester.getRect(find.byType(EncouragementTile));
          final menu = tester.getRect(
            find.byTooltip('Options du message de ${mot.fromName}'),
          );
          expect(
            carte.contains(menu.centerRight - const Offset(0.5, 0)),
            isTrue,
            reason: mot.fromName,
          );
        }
      });
    });
  }
}
