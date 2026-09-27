/// UN REFUS SE DIT AVEC LA PHRASE DE CELUI QUI REFUSE.
///
/// Toute exception autre que « hors ligne » devenait « Ça n'a pas fonctionné.
/// Réessaie dans un instant. » : cinq défis déjà ouverts, une composition à
/// 13 500 kcal, un jour de calendrier déjà fait. La personne réessayait en
/// boucle un geste qui échouerait toujours, alors que l'API avait écrit la
/// cause POUR elle.
library;

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/feedback/server_gesture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generique = 'Ça n’a pas fonctionné. Réessaie dans un instant.';
  const plafond =
      "Tu as déjà 5 défis en cours. Termines-en un avant d'en lancer un autre.";

  group('serverFailureMessage', () {
    test('un refus écrit par l’API est lu, apostrophe courbe comprise', () {
      for (final exception in <AppException>[
        const ForbiddenException(plafond, statusCode: 403, fromApi: true),
        const ValidationException(plafond, statusCode: 400, fromApi: true),
        const ValidationException(plafond, statusCode: 409, fromApi: true),
        const ValidationException(plafond, statusCode: 422, fromApi: true),
      ]) {
        expect(
          serverFailureMessage(exception),
          'Tu as déjà 5 défis en cours. Termines-en un avant d’en lancer un '
          'autre.',
          reason: '${exception.statusCode}',
        );
      }
    });

    test('un refus décidé par l’application, avant l’envoi, aussi', () {
      expect(
        serverFailureMessage(
          const ValidationException('Choisis un autre jour.'),
        ),
        'Choisis un autre jour.',
      );
    });

    test('la page d’un intermédiaire ne parle pas à la personne', () {
      // nginx, portail captif : un 403 sans l'enveloppe Carlys.
      expect(
        serverFailureMessage(
          const ForbiddenException('Forbidden', statusCode: 403),
        ),
        generique,
      );
    });

    test('une panne n’est pas un refus', () {
      expect(
        serverFailureMessage(
          const ServerException(
            'Erreur interne',
            statusCode: 500,
            fromApi: true,
          ),
        ),
        generique,
      );
      expect(serverFailureMessage(null), generique);
    });

    test('hors ligne reste hors ligne', () {
      expect(
        serverFailureMessage(const NetworkException('coupé')),
        startsWith('Hors connexion'),
      );
    });
  });

  testWidgets('runServerGesture affiche le refus du serveur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => runServerGesture(
                context,
                () async => throw const ForbiddenException(
                  plafond,
                  statusCode: 403,
                  fromApi: true,
                ),
                scope: 'Test',
              ),
              child: const Text('Lancer le défi'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Lancer le défi'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tu as déjà 5 défis en cours'), findsOneWidget);
    expect(find.text(generique), findsNothing);
  });
}
