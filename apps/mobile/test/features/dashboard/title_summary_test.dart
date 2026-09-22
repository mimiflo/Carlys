import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/title_summary.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/progression_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : l'accueil dit COMBIEN IL EN RESTE, pas
/// seulement où l'on en est.
///
/// La jauge répond à « où j'en suis » ; elle ne répond pas à « combien
/// encore ». Une barre sans son reste à parcourir ne donne rien à viser, et
/// c'est exactement ce que la carte de titre du profil disait déjà quand
/// l'accueil, lui, se taisait.
void main() {
  /// Un profil dont le total vaut `points`, réparti sur un seul axe.
  ProgressionProfile profil(int points) => ProgressionProfile(
    axes: [
      ProgressionAxis(
        value: CarlysValue.constance,
        ratio: 0,
        points: points,
        reason: 'Fixture de test.',
      ),
    ],
  );

  Widget host(ProgressionProfile? profile) => ProviderScope(
    overrides: [progressionProfileProvider.overrideWithValue(profile)],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(body: TitleSummary()),
    ),
  );

  testWidgets('le prochain palier est CHIFFRÉ, et nommé', (tester) async {
    final profile = profil(40);
    final reste = profile.pointsToNextTitle;
    final suivant = profile.title.next;

    await tester.pumpWidget(host(profile));
    await tester.pumpAndSettle();

    // On compare à ce que le BARÈME rend, pas à un nombre recopié : un
    // seuil déplacé casserait alors le barème, pas ce test.
    expect(reste, isNotNull);
    expect(suivant, isNotNull);
    // Le nombre est un fragment ACCENTUÉ dans une phrase : on cherche donc
    // la phrase entière, telle que le lecteur la lit.
    expect(
      find.textContaining('Encore $reste points avant ${suivant!.label}'),
      findsOneWidget,
    );
  });

  testWidgets('compteur fermé : aucun palier annoncé', (tester) async {
    // Annoncer un palier à quelqu'un qui n'a pas commencé, c'est lui montrer
    // une dette.
    await tester.pumpWidget(host(profil(0)));
    await tester.pumpAndSettle();

    expect(find.textContaining('points avant'), findsNothing);
  });

  testWidgets('au dernier palier, il n’y a plus de « prochain »', (
    tester,
  ) async {
    final profile = profil(maxTotal);
    expect(profile.title.next, isNull);

    await tester.pumpWidget(host(profile));
    await tester.pumpAndSettle();

    expect(find.textContaining('points avant'), findsNothing);
  });

  testWidgets('profil non lu : la carte s’efface, elle ne devine pas', (
    tester,
  ) async {
    await tester.pumpWidget(host(null));
    await tester.pumpAndSettle();

    expect(find.text('Ton titre'), findsNothing);
  });
}
