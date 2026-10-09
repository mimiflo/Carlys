import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/providers/carlys_profile_providers.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/domain/services/coach_suggestions.dart';
import 'package:carlys_mobile/features/coaching/presentation/controllers/coach_controllers.dart';
import 'package:carlys_mobile/features/coaching/presentation/providers/coach_frame_providers.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_page.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_greeting_bubble.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_message_bubble.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_coach_repository.dart';
import '../../support/fake_subscription_repository.dart';

/// L'onglet Coach, branché sur ses données.
///
/// Ce qui compte ici n'est pas le rendu — il est couvert par
/// `coach_screen_test.dart` — mais ce que l'écran fait des **refus** du
/// serveur : le droit d'accès, le plafond quotidien, la perte de réseau. Aucun
/// de ces trois cas ne doit ressembler à une panne.
void main() {
  // Aucun bonjour retenu : chaque test commence par une première ouverture.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final thread = CoachConversationSummary(
    id: '11111111-1111-4111-8111-111111111111',
    messagesCount: 2,
    updatedAt: DateTime.utc(2026, 8, 9),
  );

  Future<void> pumpPage(
    WidgetTester tester,
    FakeCoachRepository repository, {
    List<CoachSuggestion> suggestions = const [
      CoachSuggestion('Par où je commence ?', CoachSuggestionKind.start),
    ],
    bool abonne = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coachRepositoryProvider.overrideWithValue(repository),
          subscriptionRepositoryProvider.overrideWithValue(
            FakeSubscriptionRepository(coaching: abonne),
          ),
          // Les puces se calculent depuis les modèles, les records et le
          // poids : trois dépôts qui n'ont rien à faire dans ce test.
          coachSuggestionsProvider.overrideWithValue(suggestions),
          // Le profil Carlys vit sur le compte : aucun compte ici.
          currentCarlysProfileProvider.overrideWithValue(null),
          coachVoiceProvider.overrideWithValue((
            displayName: 'Florian Mottet',
            style: null,
          )),
          // Objectif, niveau, matériel : tout est choisi — la demande qui
          // les précède a son propre test (coach_frame_before_thinking).
          coachFrameMissingProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const CoachPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sans le droit, l’écran mène à Premium — pas une erreur', (
    tester,
  ) async {
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

  testWidgets('ancien abonné : l’historique se relit, l’envoi mène à '
      'Premium', (tester) async {
    await pumpPage(
      tester,
      FakeCoachRepository(
        threads: [thread],
        messages: const [
          CoachMessage(
            id: 'm-1',
            role: CoachRole.assistant,
            content: 'Ajoute une série à tes squats.',
          ),
        ],
      ),
      abonne: false,
    );

    expect(find.text('Ajoute une série à tes squats.'), findsOneWidget);
    expect(find.text('Voir Premium'), findsOneWidget);
    // Plus de composeur ni d'amorces : rien qui refuserait la question.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Par où je commence ?'), findsNothing);
  });

  testWidgets('à l’ouverture d’un fil commencé, le coach dit bonjour en bas', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeCoachRepository(
        threads: [thread],
        messages: const [
          CoachMessage(
            id: 'm-1',
            role: CoachRole.assistant,
            content: 'Ajoute une série à tes squats.',
          ),
        ],
      ),
    );

    // Un retour : il reprend, il ne se présente pas une seconde fois.
    final hello = find.textContaining('Florian !');
    expect(hello, findsOneWidget);
    expect(find.textContaining('Je suis ton coach'), findsNothing);
    final previous = find.text('Ajoute une série à tes squats.');
    expect(
      tester.getTopLeft(previous).dy,
      lessThan(tester.getTopLeft(hello).dy),
    );
  });

  testWidgets('un bonjour par jour : rouvrir l’écran ne le redit pas', (
    tester,
  ) async {
    await pumpPage(tester, FakeCoachRepository(threads: [thread]));
    expect(find.textContaining('Florian !'), findsOneWidget);

    // On ferme, on rouvre le même jour.
    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, FakeCoachRepository(threads: [thread]));
    expect(find.textContaining('Florian !'), findsNothing);
  });

  testWidgets('en lecture seule, pas de bonjour qui inviterait à écrire', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeCoachRepository(threads: [thread], messages: const []),
      abonne: false,
    );

    expect(find.textContaining('Florian'), findsNothing);
    // Ni d'amorce qui enverrait une question que le serveur refusera.
    expect(find.text('Par où je commence ?'), findsNothing);
  });

  testWidgets('hors ligne, l’écran le dit et propose de réessayer', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeCoachRepository(
        listError: const NetworkException('Serveur injoignable'),
      ),
    );

    expect(find.text('Le coach a besoin d’une connexion'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('coach coupé côté serveur : une pause, pas une erreur', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeCoachRepository(
        listError: const ServerException('coupé', statusCode: 503),
      ),
    );

    expect(find.text('Le coach est en pause'), findsOneWidget);
  });

  testWidgets('un fil vide n’est PAS créé tant qu’on n’a rien écrit', (
    tester,
  ) async {
    final repository = FakeCoachRepository();
    await pumpPage(tester, repository);

    expect(repository.createdConversations, isEmpty);
    // Le coach dit bonjour, mais rien n'est créé ni envoyé pour autant.
    expect(find.textContaining('Florian !'), findsOneWidget);
    expect(repository.sent, isEmpty);

    await tester.enterText(find.byType(TextField), 'Par où je commence ?');
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();

    // Le fil naît au moment où il a quelque chose à contenir.
    expect(repository.createdConversations, hasLength(1));
    expect(repository.sent, ['Par où je commence ?']);
  });

  testWidgets('la question et la réponse s’affichent, le champ se vide', (
    tester,
  ) async {
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

  testWidgets('une fois la première question du jour posée, les amorces '
      's’effacent', (tester) async {
    await pumpPage(tester, FakeCoachRepository(threads: [thread]));
    expect(find.text('Par où je commence ?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Où j’en suis ?');
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pump();
    // Dès l'appui, pas seulement à la réponse.
    expect(find.text('Par où je commence ?'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Par où je commence ?'), findsNothing);
  });

  testWidgets('déjà écrit aujourd’hui : pas d’amorces ; écrit hier : si', (
    tester,
  ) async {
    CoachMessage question(DateTime at) => CoachMessage(
      id: 'q-$at',
      role: CoachRole.user,
      content: 'Une question',
      createdAt: at,
    );
    final now = DateTime.now();

    await pumpPage(
      tester,
      FakeCoachRepository(threads: [thread], messages: [question(now)]),
    );
    expect(find.text('Par où je commence ?'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(
      tester,
      FakeCoachRepository(
        threads: [thread],
        messages: [question(now.subtract(const Duration(days: 1)))],
      ),
    );
    expect(find.text('Par où je commence ?'), findsOneWidget);
  });

  testWidgets('la question est dans le fil dès l’appui, avant toute réponse', (
    tester,
  ) async {
    final repository = FakeCoachRepository(threads: [thread])
      ..hangUntilCancelled = true;
    await pumpPage(tester, repository);

    await tester.enterText(find.byType(TextField), 'Où j’en suis ?');
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pump();

    expect(find.text('Où j’en suis ?'), findsOneWidget);
    // Le serveur n'a rien rendu : seule la question est là, sous le bonjour
    // (sa bulle, quel que soit son état : l'attente se compte en temps réel).
    final hello = find.byType(CoachGreetingBubble);
    expect(
      tester.getTopLeft(hello).dy,
      lessThan(tester.getTopLeft(find.text('Où j’en suis ?')).dy),
    );
    await tester.tap(find.bySemanticsLabel('Arrêter'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'au plafond du jour, le refus est expliqué et la question reste',
    (tester) async {
      final repository = FakeCoachRepository(
        threads: [thread],
        sendError: const ServerException('plafond', statusCode: 429),
      );
      await pumpPage(tester, repository);

      await tester.enterText(find.byType(TextField), 'Encore une');
      await tester.tap(find.bySemanticsLabel('Envoyer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('nombre de messages du jour'), findsOneWidget);
      // Rien n'est perdu : le texte est toujours là, prêt à repartir demain.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Encore une',
      );
    },
  );

  testWidgets('réseau perdu à l’envoi : le composeur bascule hors ligne', (
    tester,
  ) async {
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

  testWidgets('hors ligne : « Réessayer » rouvre le composeur', (tester) async {
    // Le drapeau hors ligne ne se levait QUE dans `send()` — or hors ligne,
    // le composeur et les suggestions disparaissent, donc `send()` était
    // inatteignable : le coach restait muet jusqu'à ce qu'on quitte l'écran,
    // réseau revenu ou non. Une coupure d'une seconde condamnait l'accès.
    final repository = FakeCoachRepository(
      threads: [thread],
      sendError: const NetworkException('Serveur injoignable'),
    );
    await pumpPage(tester, repository);

    await tester.enterText(find.byType(TextField), 'Une question');
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('besoin d’une connexion'), findsNothing);
  });
}
