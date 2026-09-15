import 'package:carlys_mobile/features/community/presentation/controllers/community_controllers.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/friend_code_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : la carte du code ami promettait, en cas
/// d'échec, que « ton code arrivera avec la connexion ». C'était faux.
/// `myFriendCodeProvider` n'est pas auto-disposé — un code est attribué à vie
/// et ne doit pas changer sous la feuille — donc l'échec restait mémoïsé pour
/// TOUTE la session : ni le retour du réseau, ni la fermeture puis la
/// réouverture de la feuille ne le rejouaient.
void main() {
  testWidgets('après un échec, toucher la carte recharge vraiment le code', (
    tester,
  ) async {
    var appels = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myFriendCodeProvider.overrideWith((ref) async {
            appels += 1;
            if (appels == 1) {
              throw Exception('hors ligne');
            }
            return 'CARLYS-ABCD';
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: FriendCodeCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final invite = find.textContaining('Touche pour réessayer');
    expect(invite, findsOneWidget);

    await tester.tap(invite);
    await tester.pumpAndSettle();

    expect(appels, 2, reason: 'la lecture doit être RELANCÉE, pas resservie');
    expect(find.textContaining('Touche pour réessayer'), findsNothing);
  });

  testWidgets('la reprise s’annonce comme un bouton aux lecteurs d’écran', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myFriendCodeProvider.overrideWith(
            (ref) async => throw Exception('hors ligne'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: FriendCodeCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // La phrase affichée sert de libellé — elle dit déjà la cause ET le
    // geste. Ce qui manquait aux lecteurs d'écran, c'est qu'elle SOIT un
    // bouton : sans ce drapeau, elle se lit comme un simple constat d'échec.
    final noeud = tester.getSemantics(
      find.textContaining('Touche pour réessayer'),
    );
    expect(noeud.flagsCollection.isButton, isTrue);
    handle.dispose();
  });
}
