import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_app.dart';
import '../../support/fake_community_repository.dart';
import '../../support/first_run_prefs.dart';

/// LES DEUX DERNIÈRES SOURCES DE L'ÉCRAN COMMUNAUTÉ.
///
/// L'arbitrage erreur / chargement / vide avait été écrit pour cinq sources.
/// La ligue et les défis entre amis sont arrivés ensuite, et personne ne les
/// y a ajoutés : leur panne effaçait leur section sans rien dire, sous un
/// écran qui se déclarait par ailleurs en bon état.
///
/// Et le geste « tirer pour rafraîchir » attendait un `Future.wait` que
/// personne n'entourait : hors ligne, il levait une exception non traitée.
void main() {
  setUp(() {
    seedCompletedFirstRun();
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('une LIGUE en panne n’est pas un écran vide', (tester) async {
    // « Personne ici » serait un mensonge : le serveur a refusé de répondre.
    final community = FakeCommunityRepository()
      ..leagueError = StateError('ligue injoignable (voulu par le test)');
    await openCommunity(tester, appWith(community));

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.byType(AppEmptyState), findsNothing);
  });

  testWidgets('tirer pour rafraîchir HORS LIGNE ne jette pas dans le vide', (
    tester,
  ) async {
    // Le dépôt part en bon état pour que l'écran ait des données, puis tombe
    // : c'est le cas réel — on ouvre connecté, on rafraîchit sans réseau.
    final community = FakeCommunityRepository();
    await openCommunity(tester, appWith(community));

    community.offline = true;
    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 320),
      1000,
    );
    await tester.pumpAndSettle();

    // Aucune exception non traitée : `flutter_test` ferait échouer le test.
    // Et l'écran DIT la panne, il ne se contente pas de ne rien faire.
    expect(find.byType(AppErrorState), findsOneWidget);
  });
}
