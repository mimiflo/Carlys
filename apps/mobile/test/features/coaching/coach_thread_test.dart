import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_session_launcher.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/controllers/coach_controllers.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // La question en cours se garde sur l'appareil (reprise au retour).
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

    test('les droits se lisent PENDANT la liste des fils, pas après', () async {
      final repository = FakeCoachRepository(threads: [ancien])
        ..listGate = Completer<void>();
      final droits = FakeSubscriptionRepository(coaching: true);
      final container = ProviderContainer(
        overrides: [
          coachRepositoryProvider.overrideWithValue(repository),
          subscriptionRepositoryProvider.overrideWithValue(droits),
        ],
      );
      addTearDown(container.dispose);

      final etat = container.read(coachThreadProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(droits.entitlementsReads, 1);

      repository.listGate!.complete();
      expect((await etat).isReadOnly, isFalse);
      expect(droits.entitlementsReads, 1);
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

  // Relire n'a pas besoin du réseau : l'écriture, si (voir `CoachRepository`).
  group('hors ligne : le dernier fil gardé reste à relire', () {
    const coupure = NetworkException('hors ligne');
    const garde = CoachConversation(id: 'fil-garde', messages: echange);

    test('le fil gardé s’affiche, composeur hors ligne', () async {
      final container = containerWith(
        FakeCoachRepository(listError: coupure, cached: garde),
      );

      final etat = await container.read(coachThreadProvider.future);

      expect(etat.conversation.id, 'fil-garde');
      expect(etat.conversation.messages, hasLength(2));
      expect(etat.isOffline, isTrue);
    });

    test('rien de gardé : l’état hors ligne, comme avant', () async {
      final container = containerWith(FakeCoachRepository(listError: coupure));

      await expectLater(
        container.read(coachThreadProvider.future),
        throwsA(isA<NetworkException>()),
      );
    });

    test('« Réessayer » relit le serveur, réseau revenu', () async {
      final repository = FakeCoachRepository(
        threads: [ancien],
        messages: [...echange, echange.first],
        listError: coupure,
        cached: garde,
      );
      final container = containerWith(repository);
      await container.read(coachThreadProvider.future);

      repository.listError = null;
      container.read(coachThreadProvider.notifier).clearOffline();
      final etat = await container.read(coachThreadProvider.future);

      expect(etat.conversation.id, ancien.id);
      expect(etat.conversation.messages, hasLength(3));
      expect(etat.isOffline, isFalse);
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

  test(
    'la question s’affiche aussitôt, la réponse s’écrit, puis s’archive',
    () async {
      final repository = FakeCoachRepository()..streamed = ['Repos ', 'actif.'];
      final container = containerWith(repository);
      await container.read(coachThreadProvider.future);
      final lives = <CoachLiveTurn?>[];
      container.listen(
        coachThreadProvider,
        (_, next) => lives.add(next.valueOrNull?.live),
      );

      expect(
        await container.read(coachThreadProvider.notifier).send(' Demain ? '),
        isTrue,
      );

      expect(lives.map((live) => live?.text), [
        '',
        'Repos ',
        'Repos actif.',
        null,
      ]);
      expect(lives.first?.question, 'Demain ?');
      final etat = container.read(coachThreadProvider).valueOrNull;
      expect(etat?.isSending, isFalse);
      expect(etat?.conversation.messages.map((m) => m.content), [
        'Demain ?',
        'Bien reçu.',
      ]);
    },
  );

  test('un échec en cours de route efface le tour en direct', () async {
    final repository = FakeCoachRepository(
      sendError: const ServerException('panne', statusCode: 503),
    );
    final container = containerWith(repository);
    await container.read(coachThreadProvider.future);

    await container.read(coachThreadProvider.notifier).send('Demain ?');

    final etat = container.read(coachThreadProvider).valueOrNull;
    expect(etat?.live, isNull);
    expect(etat?.notice, 'Le coach est momentanément indisponible.');
  });

  test(
    'question déjà en cours (409, par HTTP ou par le flux) : on attend sa réponse, sans avis',
    () {
      // Le serveur l'écrit encore (page quittée puis rouverte) : la MÊME
      // question se redemande jusqu'à ce que sa réponse archivée revienne.
      for (final refus in const <AppException>[
        ValidationException('déjà en cours', statusCode: 409),
        ServerException('déjà en cours', statusCode: 409),
      ]) {
        fakeAsync((async) {
          final repository = FakeCoachRepository(sendError: refus);
          final container = containerWith(repository);
          container.listen(coachThreadProvider, (_, __) {});
          container.read(coachThreadProvider.future);
          async.flushMicrotasks();

          bool? parti;
          container
              .read(coachThreadProvider.notifier)
              .send('Demain ?')
              .then((value) => parti = value);
          async.elapse(const Duration(seconds: 7));
          var etat = container.read(coachThreadProvider).valueOrNull;
          expect(etat?.isSending, isTrue);
          expect(etat?.notice, isNull);

          repository.sendError = null;
          async.elapse(const Duration(seconds: 3));
          etat = container.read(coachThreadProvider).valueOrNull;
          expect(parti, isTrue);
          expect(etat?.conversation.messages.last.content, 'Bien reçu.');
          expect(repository.sentIds.toSet(), hasLength(1));
        });
      }
    },
  );

  group('file d’attente, arrêt, saturation (ADR 0013)', () {
    test('sa réflexion s’affiche en direct, étape par étape', () async {
      final repository = FakeCoachRepository()
        ..steps = ['Je regarde tes records', 'Je prépare ta séance']
        ..hangUntilCancelled = true;
      final container = containerWith(repository);
      container.listen(coachThreadProvider, (_, __) {});
      await container.read(coachThreadProvider.future);

      final sent = container
          .read(coachThreadProvider.notifier)
          .send('Mon record ?');
      await pumpEventQueue();

      expect(container.read(coachThreadProvider).valueOrNull?.live?.steps, [
        'Je regarde tes records',
        'Je prépare ta séance',
      ]);
      container.read(coachThreadProvider.notifier).stop();
      await sent;
    });

    test('en file : la bulle sait combien passent avant', () async {
      final repository = FakeCoachRepository()
        ..queued = [2, 1]
        ..hangUntilCancelled = true;
      final container = containerWith(repository);
      // Un écran l'écoute : sans lui, le fil autoDispose partirait pendant
      // que la réponse se fait attendre.
      container.listen(coachThreadProvider, (_, __) {});
      await container.read(coachThreadProvider.future);

      final sent = container
          .read(coachThreadProvider.notifier)
          .send('Demain ?');
      await pumpEventQueue();

      expect(container.read(coachThreadProvider).valueOrNull?.live?.ahead, 1);
      container.read(coachThreadProvider.notifier).stop();
      await sent;
    });

    test(
      '« Arrêter » : plus de tour en cours, ni avis ni hors ligne, la question reste à renvoyer',
      () async {
        final repository = FakeCoachRepository()..hangUntilCancelled = true;
        final container = containerWith(repository);
        container.listen(coachThreadProvider, (_, __) {});
        await container.read(coachThreadProvider.future);

        final sent = container
            .read(coachThreadProvider.notifier)
            .send('Demain ?');
        await pumpEventQueue();
        expect(
          container.read(coachThreadProvider).valueOrNull?.isSending,
          isTrue,
        );

        container.read(coachThreadProvider.notifier).stop();

        expect(await sent, isFalse, reason: 'le champ garde la question');
        final etat = container.read(coachThreadProvider).valueOrNull;
        expect(etat?.live, isNull);
        expect(etat?.notice, isNull);
        expect(etat?.isOffline, isFalse);

        // Renvoyée telle quelle : MÊME identifiant, aucun doublon côté serveur.
        repository.hangUntilCancelled = false;
        await container.read(coachThreadProvider.notifier).send('Demain ?');
        expect(repository.sentIds.toSet(), hasLength(1));
      },
    );

    test(
      'très sollicité : un avis qui invite à réessayer, pas une panne',
      () async {
        final container = containerWith(
          FakeCoachRepository(
            sendError: const ServerException(
              'Le coach est très sollicité en ce moment. Réessaie dans un instant.',
              code: 'SERVICE_BUSY',
              statusCode: 503,
              fromApi: true,
            ),
          ),
        );
        await container.read(coachThreadProvider.future);

        expect(
          await container.read(coachThreadProvider.notifier).send('Demain ?'),
          isFalse,
        );
        expect(
          container.read(coachThreadProvider).valueOrNull?.notice,
          'Le coach est très sollicité en ce moment. Réessaie dans un instant.',
        );
      },
    );

    test(
      'un 429 du serveur dit LEQUEL des plafonds : son message fait foi',
      () async {
        final container = containerWith(
          FakeCoachRepository(
            sendError: const ServerException(
              'Tu envoies trop de messages d’un coup. Attends une minute.',
              statusCode: 429,
              fromApi: true,
            ),
          ),
        );
        await container.read(coachThreadProvider.future);

        await container.read(coachThreadProvider.notifier).send('Demain ?');
        expect(
          container.read(coachThreadProvider).valueOrNull?.notice,
          'Tu envoies trop de messages d’un coup. Attends une minute.',
        );
      },
    );
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
