import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/controllers/coach_controllers.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_page.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_coach_repository.dart';

/// L'onglet Coach, branché sur ses données.
///
/// Ce qui compte ici n'est pas le rendu — il est couvert par
/// `coach_screen_test.dart` — mais ce que l'écran fait des **refus** du
/// serveur : le droit d'accès, le plafond quotidien, la perte de réseau. Aucun
/// de ces trois cas ne doit ressembler à une panne.
void main() {
  final thread = CoachConversationSummary(
    id: '11111111-1111-4111-8111-111111111111',
    messagesCount: 2,
    updatedAt: DateTime.utc(2026, 8, 9),
  );

  Future<void> pumpPage(
    WidgetTester tester,
    FakeCoachRepository repository, {
    List<String> suggestions = const ['Par où je commence ?'],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coachRepositoryProvider.overrideWithValue(repository),
          // Les puces se calculent depuis les modèles, les records et le
          // poids : trois dépôts qui n'ont rien à faire dans ce test.
          coachSuggestionsProvider.overrideWithValue(suggestions),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const CoachPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sans le droit, l’écran mène à Premium — pas une erreur',
      (tester) async {
    await pumpPage(
      tester,
      FakeCoachRepository(
        listError: const ForbiddenException('ai_coaching requis'),
      ),
    );

    expect(find.text('Le coach est réservé à Premium'), findsOneWidget);
    expect(find.text('Voir Premium'), findsOneWidget);
    // Surtout pas le vocabulaire de la panne : ce n'est pas cassé.
    expect(find.text('Coach indisponible'), findsNothing);
  });

  testWidgets('hors ligne, l’écran le dit et propose de réessayer',
      (tester) async {
    await pumpPage(
      tester,
      FakeCoachRepository(
        listError: const NetworkException('Serveur injoignable'),
      ),
    );

    expect(find.text('Le coach a besoin d’une connexion'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('coach coupé côté serveur : une pause, pas une erreur',
      (tester) async {
    await pumpPage(
      tester,
      FakeCoachRepository(
        listError: const ServerException('coupé', statusCode: 503),
      ),
    );

    expect(find.text('Le coach est en pause'), findsOneWidget);
  });

  testWidgets('un fil vide n’est PAS créé tant qu’on n’a rien écrit',
      (tester) async {
    final repository = FakeCoachRepository();
    await pumpPage(tester, repository);

    expect(repository.createdConversations, isEmpty);
    expect(find.text('Ton coach est là'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Par où je commence ?');
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();

    // Le fil naît au moment où il a quelque chose à contenir.
    expect(repository.createdConversations, hasLength(1));
    expect(repository.sent, ['Par où je commence ?']);
  });

  testWidgets('la question et la réponse s’affichent, le champ se vide',
      (tester) async {
    final repository = FakeCoachRepository(threads: [thread]);
    await pumpPage(tester, repository);

    await tester.enterText(find.byType(TextField), 'Où j’en suis ?');
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();

    expect(find.byType(CoachMessageBubble), findsNWidgets(2));
    expect(find.text('Bien reçu.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('au plafond du jour, le refus est expliqué et la question reste',
      (tester) async {
    final repository = FakeCoachRepository(
      threads: [thread],
      sendError: const ServerException('plafond', statusCode: 429),
    );
    await pumpPage(tester, repository);

    await tester.enterText(find.byType(TextField), 'Encore une');
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('nombre de messages du jour'),
      findsOneWidget,
    );
    // Rien n'est perdu : le texte est toujours là, prêt à repartir demain.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Encore une',
    );
  });

  testWidgets('réseau perdu à l’envoi : le composeur bascule hors ligne',
      (tester) async {
    final repository = FakeCoachRepository(
      threads: [thread],
      sendError: const NetworkException('Serveur injoignable'),
    );
    await pumpPage(tester, repository);

    await tester.enterText(find.byType(TextField), 'Une question');
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('besoin d’une connexion'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
