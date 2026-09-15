import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/add_friend_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/in_memory_community_repository.dart';

/// La feuille « Ajouter un ami » : un champ pour deux identités (e-mail ou
/// code), et mon propre code en tête, prêt à être scanné.
void main() {
  /// Ouvre la feuille et rend une BOÎTE que l'appelant relira APRÈS coup.
  ///
  /// L'ancien helper rendait `result` juste après l'ouverture : la feuille
  /// n'était pas encore refermée, la valeur était donc `null` à coup sûr, et
  /// les deux tests qui promettaient « la forme canonique » et « le chemin
  /// e-mail » n'assertaient en réalité qu'une chose — que la feuille s'était
  /// fermée. Une boîte partagée se relit une fois le geste terminé.
  Future<_Resultat> pumpAndOpen(WidgetTester tester) async {
    final boite = _Resultat();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityRepositoryProvider.overrideWithValue(
            InMemoryCommunityRepository(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    boite.valeur = await showAddFriendSheet(context);
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
    return boite;
  }

  testWidgets('mon code s’affiche en XXXX-XXXX avec son QR', (tester) async {
    await pumpAndOpen(tester);

    // Le dépôt d'exemple répond CWDEM742 : la feuille l'affiche coupé en deux.
    expect(find.text('CWDE-M742'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('un code tapé — même mal fagoté — sort en forme canonique', (
    tester,
  ) async {
    final resultat = await pumpAndOpen(tester);
    await tester.enterText(find.byType(TextFormField), ' ac23-def4 ');
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();

    // La feuille est fermée ET son résultat est celui qu'on attend : c'est la
    // SECONDE moitié qui manquait, et c'était toute la promesse du titre.
    expect(find.text('Envoyer la demande'), findsNothing);
    expect(resultat.valeur, isA<AddFriendByCode>());
    expect((resultat.valeur! as AddFriendByCode).code, 'AC23DEF4');
  });

  testWidgets('une adresse e-mail emprunte l’autre chemin', (tester) async {
    final resultat = await pumpAndOpen(tester);
    await tester.enterText(find.byType(TextFormField), 'ami@exemple.fr');
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();

    expect(find.text('Envoyer la demande'), findsNothing);
    expect(resultat.valeur, isA<AddFriendByEmail>());
    expect((resultat.valeur! as AddFriendByEmail).email, 'ami@exemple.fr');
  });

  testWidgets('une saisie qui n’est ni l’un ni l’autre est retenue au bord', (
    tester,
  ) async {
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

/// Une boîte que le test remplit à la FERMETURE de la feuille et relit
/// ensuite. Sans elle, la valeur se lisait avant d'exister.
class _Resultat {
  AddFriendInput? valeur;
}
