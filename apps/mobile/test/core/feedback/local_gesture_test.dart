/// Un geste local qui échoue le DIT — même quand il échoue sur une `Error`.
///
/// C'est toute la raison d'être de `runLocalGesture` à côté de
/// `runServerGesture` : la règle « au plus une séance en cours » se défend
/// par un `StateError`, qui est une `Error` et non une `Exception`. Un filet
/// écrit `on Exception` la laisse filer, et une série saisie disparaît sans
/// message, sans navigation, sans rien — le bouton semble n'avoir pas
/// répondu.
library;

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/feedback/server_gesture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> aboutis;

  /// Un écran minimal dont le bouton lance [geste] à travers le filet.
  Widget ecran(Future<void> Function() geste) {
    aboutis = [];
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final abouti = await runLocalGesture(
                context,
                geste,
                scope: 'Test',
                echec: 'La série n’a pas pu être enregistrée. Réessaie.',
              );
              aboutis.add(abouti ? 'abouti' : 'échoué');
            },
            child: const Text('Faire'),
          ),
        ),
      ),
    );
  }

  Future<void> appuyer(WidgetTester tester) async {
    await tester.tap(find.text('Faire'));
    await tester.pumpAndSettle();
  }

  testWidgets('un geste qui aboutit ne dit rien, et le signale', (
    tester,
  ) async {
    await tester.pumpWidget(ecran(() async {}));
    await appuyer(tester);

    expect(aboutis, ['abouti']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'une Error est attrapée et affichée — pas seulement une Exception',
    (tester) async {
      await tester.pumpWidget(
        ecran(() async => throw StateError('Une séance est déjà en cours.')),
      );
      await appuyer(tester);

      expect(aboutis, ['échoué']);
      expect(
        find.text('La série n’a pas pu être enregistrée. Réessaie.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('une Exception passe par le même chemin', (tester) async {
    await tester.pumpWidget(
      ecran(() async => throw const NetworkException('hors ligne')),
    );
    await appuyer(tester);

    expect(aboutis, ['échoué']);
    expect(
      find.text('La série n’a pas pu être enregistrée. Réessaie.'),
      findsOneWidget,
    );
  });
}
