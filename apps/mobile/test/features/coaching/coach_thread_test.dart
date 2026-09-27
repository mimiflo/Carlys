import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_session_launcher.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/controllers/coach_controllers.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_coach_repository.dart';
import '../../support/fake_subscription_repository.dart';

/// Lanceur de test : compte les séances créées, sans base ni synchronisation.
class _CountingLauncher implements CoachSessionLauncher {
  final List<String> started = [];

  @override
  Future<String> start(CoachSessionProposal proposal) async {
    final id = 'seance-${started.length + 1}';
    started.add(id);
    return id;
  }
}

/// Le fil du coach, vu du contrôleur.
///
/// Deux défauts se jouaient ici, et tous deux coûtent de l'argent ou de la
/// confiance : l'identifiant de message, clé d'idempotence du serveur, était
/// tiré à neuf à chaque tentative — une réponse perdue en route faisait donc
/// facturer deux fois la même question ; et le refus précédent revenait se
/// coller sous la réponse qu'on venait tout juste de recevoir.
void main() {
  ProviderContainer containerWith(
    FakeCoachRepository repository, {
    bool abonne = true,
    Object? droitsEnPanne,
  }) {
    final container = ProviderContainer(
      overrides: [
        coachRepositoryProvider.overrideWithValue(repository),
        subscriptionRepositoryProvider.overrideWithValue(
          FakeSubscriptionRepository(
            coaching: abonne,
            entitlementsError: droitsEnPanne,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  final ancien = CoachConversationSummary(
    id: '11111111-1111-4111-8111-111111111111',
    messagesCount: 2,
    updatedAt: DateTime.utc(2026, 8, 9),
  );
  const echange = [
    CoachMessage(id: 'm-1', role: CoachRole.user, content: 'Et mes squats ?'),
    CoachMessage(
      id: 'm-2',
      role: CoachRole.assistant,
      content: 'Ajoute une série.',
    ),
  ];

  group('ancien abonné : l’historique reste à relire', () {
    // Les CGU promettent que ce qui a été créé avec le Premium reste
    // consultable. La lecture est ouverte à l'auteur ; seuls la création
    // d'un fil et l'envoi demandent le droit au coach.
    test('le fil se relit, en lecture seule', () async {
      final container = containerWith(
        FakeCoachRepository(threads: [ancien], messages: echange),
        abonne: false,
      );

      final etat = await container.read(coachThreadProvider.future);

      expect(etat.conversation.messages, hasLength(2));
      expect(etat.isReadOnly, isTrue);
    });

    test('sans historique ni droit : l’invitation à l’abonnement', () async {
      final container = containerWith(FakeCoachRepository(), abonne: false);

      await expectLater(
        container.read(coachThreadProvider.future),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('un envoi refusé (403) passe le fil en lecture seule', () async {
      final repository = FakeCoachRepository(
        threads: [ancien],
        messages: echange,
        sendError: const ForbiddenException(
          'Le coach est réservé aux abonnés.',
          statusCode: 403,
          fromApi: true,
        ),
      );
      final container = containerWith(repository);
      await container.read(coachThreadProvider.future);

      final parti = await container
          .read(coachThreadProvider.notifier)
          .send('Encore une ?');

      expect(parti, isFalse);
      final etat = container.read(coachThreadProvider).requireValue;
      expect(etat.isReadOnly, isTrue);
      expect(etat.conversation.messages, hasLength(2));
    });
  });

  // `GET /entitlements` en échec ponctuel (délai, 5xx) chez un abonné qui
  // PAIE : le droit est inconnu, pas refusé. L'envoi rapportera le vrai
  // refus s'il y en a un.
  group('droit inconnu : l’écriture reste permise', () {
    const panne = ServerException('droits indisponibles');

    test('avec un historique, le fil reste ouvert', () async {
      final container = containerWith(
        FakeCoachRepository(threads: [ancien], messages: echange),
        droitsEnPanne: panne,
      );

      final etat = await container.read(coachThreadProvider.future);

      expect(etat.isReadOnly, isFalse);
    });

    test('sans historique, un fil neuf plutôt que l’invitation', () async {
      final container = containerWith(
        FakeCoachRepository(),
        droitsEnPanne: panne,
      );

      final etat = await container.read(coachThreadProvider.future);

      expect(etat.conversation.messages, isEmpty);
      expect(etat.isReadOnly, isFalse);
    });
  });

  test('une même question rejouée garde SON identifiant', () async {
    final repository = FakeCoachRepository(
      sendError: const NetworkException('coupure'),
    );
    final container = containerWith(repository);
    await container.read(coachThreadProvider.future);
    final thread = container.read(coachThreadProvider.notifier);

    expect(await thread.send('Par où je commence ?'), isFalse);
    // Le réseau revient : la personne réappuie sur la même question.
    repository.sendError = null;
    expect(await thread.send('Par où je commence ?'), isTrue);

    expect(repository.sentIds, hasLength(2));
    // Le serveur reconnaît le rejeu : un seul message, un seul décompte.
    expect(repository.sentIds.first, repository.sentIds.last);
  });

  test('une AUTRE question prend un identifiant neuf', () async {
    // Réutiliser l'identifiant ferait rendre au serveur la réponse de la
    // question précédente : l'idempotence porte sur le message, pas sur
    // l'envoi.
    final repository = FakeCoachRepository(
      sendError: const NetworkException('coupure'),
    );
    final container = containerWith(repository);
    await container.read(coachThreadProvider.future);
    final thread = container.read(coachThreadProvider.notifier);

    await thread.send('Par où je commence ?');
    repository.sendError = null;
    await thread.send('Et pour les jambes ?');

    expect(repository.sentIds.first, isNot(repository.sentIds.last));
  });

  test('un envoi réussi efface le refus précédent', () async {
    final repository = FakeCoachRepository(
      sendError: const ServerException('plafond', statusCode: 429),
    );
    final container = containerWith(repository);
    await container.read(coachThreadProvider.future);
    final thread = container.read(coachThreadProvider.notifier);

    await thread.send('Une question de trop');
    expect(
      container.read(coachThreadProvider).valueOrNull?.notice,
      contains('nombre de messages du jour'),
    );

    repository.sendError = null;
    expect(await thread.send('Demain, donc'), isTrue);

    // Le message d'avant se recollait sous la réponse fraîche : l'état
    // repris pour construire le succès était celui d'AVANT l'envoi.
    expect(container.read(coachThreadProvider).valueOrNull?.notice, isNull);
  });

  group('proposition déjà acceptée', () {
    const proposition = CoachSessionProposal(
      id: 'proposition-1',
      name: 'Haut du corps',
      estimatedMinutes: 25,
      exercises: [],
    );

    ({
      ProviderContainer container,
      _CountingLauncher launcher,
      FakeCoachRepository repository,
    })
    banc() {
      final launcher = _CountingLauncher();
      final repository = FakeCoachRepository();
      final container = ProviderContainer(
        overrides: [
          coachRepositoryProvider.overrideWithValue(repository),
          coachSessionLauncherProvider.overrideWithValue(launcher),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, launcher: launcher, repository: repository);
    }

    test('ramène à SA séance au lieu d’en créer une seconde', () async {
      // Le serveur dit déjà quelle séance en est née. Sans ce garde-fou,
      // rouvrir le fil et réappuyer fabriquait une séance de plus à chaque
      // fois — l'historique se remplissait de séances jamais faites.
      final b = banc();

      final sessionId = await b.container
          .read(coachProposalActionsProvider)
          .start(
            const CoachSessionProposal(
              id: 'proposition-1',
              name: 'Haut du corps',
              estimatedMinutes: 25,
              exercises: [],
              acceptedSessionId: 'seance-deja-la',
            ),
          );

      expect(sessionId, 'seance-deja-la');
      expect(b.launcher.started, isEmpty);
      // Et l'acceptation n'est pas re-signalée : elle l'est déjà.
      expect(b.repository.accepted, isEmpty);
    });

    test('une proposition NEUVE se lance normalement', () async {
      final b = banc();

      final sessionId = await b.container
          .read(coachProposalActionsProvider)
          .start(proposition);

      expect(sessionId, 'seance-1');
      expect(b.repository.accepted, hasLength(1));
    });
  });
}
