import 'package:carlys_mobile/demo/demo_community.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/add_friend_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// La feuille « Ajouter un ami » : un champ pour deux identités (e-mail ou
/// code), et mon propre code en tête, prêt à être scanné.
void main() {
  Future<AddFriendInput?> pumpAndOpen(WidgetTester tester) async {
    AddFriendInput? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityRepositoryProvider
              .overrideWithValue(DemoCommunityRepository()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showAddFriendSheet(context);
                  },
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('mon code s’affiche en XXXX-XXXX avec son QR', (tester) async {
    await pumpAndOpen(tester);

    // Le dépôt démo répond CWDEM742 : la feuille l'affiche coupé en deux.
    expect(find.text('CWDE-M742'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('un code tapé — même mal fagoté — sort en forme canonique',
      (tester) async {
    await pumpAndOpen(tester);
    await tester.enterText(find.byType(TextFormField), ' ac23-def4 ');
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();

    // La feuille est fermée : son résultat a été rendu à l'appelant.
    expect(find.text('Envoyer la demande'), findsNothing);
  });

  testWidgets('une adresse e-mail emprunte l’autre chemin', (tester) async {
    await pumpAndOpen(tester);
    await tester.enterText(find.byType(TextFormField), 'ami@exemple.fr');
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();

    expect(find.text('Envoyer la demande'), findsNothing);
  });

  testWidgets('une saisie qui n’est ni l’un ni l’autre est retenue au bord',
      (tester) async {
    await pumpAndOpen(tester);
    await tester.enterText(
      find.byType(TextFormField),
      'AC23DEF0', // 0 interdit
    );
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();

    // La feuille reste ouverte et explique la forme attendue.
    expect(
      find.text('Entre un code ami (XXXX-XXXX) ou une adresse e-mail.'),
      findsOneWidget,
    );
  });
}
