import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/coaching/data/coach_pending_store.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/domain/services/coach_reply_awaiter.dart';
import 'package:carlys_mobile/features/coaching/presentation/controllers/coach_controllers.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_coach_repository.dart';
import '../../support/fake_subscription_repository.dart';

/// Page quittée, appli fermée : le serveur finit la réponse, l'appli la
/// reprend au retour — sans reposer la question, ni la compter deux fois.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const store = CoachPendingStore();
  const fil = '11111111-1111-4111-8111-111111111111';
  final ilYA = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
  final summary = CoachConversationSummary(
    id: fil,
    messagesCount: 1,
    updatedAt: ilYA,
  );
  const question = CoachMessage(
    id: 'q-1',
    role: CoachRole.user,
    content: 'Une séance jambes ?',
  );
  const reponse = CoachMessage(
    id: 'r-1',
    role: CoachRole.assistant,
    content: 'Voici ta séance.',
  );
  final enAttente = (
    conversationId: fil,
    id: 'q-1',
    content: 'Une séance jambes ?',
    since: ilYA,
  );
  const archivee = CoachReply(
    userMessage: question,
    assistantMessage: reponse,
    remainingToday: 28,
  );

  ProviderContainer containerWith(FakeCoachRepository repository) {
    final container = ProviderContainer(
      overrides: [
        coachRepositoryProvider.overrideWithValue(repository),
        subscriptionRepositoryProvider.overrideWithValue(
          FakeSubscriptionRepository(coaching: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('awaitCoachReply', () {
    const occupe = ValidationException('en cours', statusCode: 409);

    test('409 : redemande jusqu’à la réponse archivée', () {
      fakeAsync((async) {
        var essais = 0;
        CoachReply? rendue;
        awaitCoachReply(() async {
          if (++essais < 3) throw occupe;
          return archivee;
        }, stopped: () => false).then((r) => rendue = r);
        async.elapse(const Duration(seconds: 6));
        expect(essais, 3);
        expect(rendue, same(archivee));
      });
    });

    test('409 au-delà de l’échéance : le refus remonte', () {
      fakeAsync((async) {
        Object? erreur;
        awaitCoachReply(
          () async => throw occupe,
          stopped: () => false,
          giveUpAfter: const Duration(seconds: 9),
        ).then(
          (_) {},
          onError: (Object e) {
            erreur = e;
          },
        );
        async.elapse(const Duration(seconds: 30));
        expect(erreur, same(occupe));
      });
    });

    test('arrêtée pendant l’attente : plus aucune demande', () {
      fakeAsync((async) {
        var essais = 0;
        var arrete = false;
        Object? erreur;
        awaitCoachReply(() async {
          essais++;
          throw occupe;
        }, stopped: () => arrete).then(
          (_) {},
          onError: (Object e) {
            erreur = e;
          },
        );
        async.elapse(const Duration(seconds: 1));
        arrete = true;
        async.elapse(const Duration(seconds: 30));
        expect(essais, 1);
        expect(erreur, isA<UnknownException>());
      });
    });

    test('un autre refus remonte aussitôt', () async {
      var essais = 0;
      await expectLater(
        awaitCoachReply(() async {
          essais++;
          throw const ServerException('panne', statusCode: 503);
        }, stopped: () => false),
        throwsA(isA<ServerException>()),
      );
      expect(essais, 1);
    });
  });

  group('CoachPendingStore', () {
    test('se garde, se relit, s’efface', () async {
      await store.save(enAttente);
      expect(await store.read(), enAttente);
      await store.clear();
      expect(await store.read(), isNull);
    });

    test('illisible : rien à reprendre, jamais une erreur', () async {
      SharedPreferences.setMockInitialValues({CoachPendingStore.key: '{'});
      expect(await store.read(), isNull);
    });
  });

  group('retour sur la page', () {
    test(
      'question sans réponse : le tour reprend, la réponse s’ajoute UNE fois',
      () async {
        await store.save(enAttente);
        final repository = FakeCoachRepository(
          threads: [summary],
          messages: const [question],
          reply: archivee,
        );
        final container = containerWith(repository);
        container.listen(coachThreadProvider, (_, __) {});

        final ouvert = await container.read(coachThreadProvider.future);
        expect(ouvert.live?.question, 'Une séance jambes ?');
        expect(ouvert.live?.since, ilYA, reason: 'le chrono reprend');

        await pumpEventQueue();
        final etat = container.read(coachThreadProvider).valueOrNull;
        expect(repository.sentIds, ['q-1'], reason: 'même clé, aucun doublon');
        expect(etat?.isSending, isFalse);
        expect(etat?.conversation.messages.map((m) => m.id), ['q-1', 'r-1']);
        expect(await store.read(), isNull);
      },
    );

    test('déjà répondue pendant l’absence : rien à reprendre', () async {
      await store.save(enAttente);
      final repository = FakeCoachRepository(
        threads: [summary],
        messages: const [question, reponse],
      );
      final container = containerWith(repository);

      final ouvert = await container.read(coachThreadProvider.future);
      expect(ouvert.live, isNull);
      expect(repository.sent, isEmpty);
      expect(await store.read(), isNull);
    });
  });

  test(
    'plus vieille que l’attente permise : oubliée, jamais reposée seule',
    () async {
      await store.save((
        conversationId: fil,
        id: 'q-1',
        content: 'Une séance jambes ?',
        since: DateTime.now().toUtc().subtract(const Duration(hours: 20)),
      ));
      final repository = FakeCoachRepository(
        threads: [summary],
        messages: const [question],
      );
      final container = containerWith(repository);

      final ouvert = await container.read(coachThreadProvider.future);
      expect(ouvert.live, isNull);
      await pumpEventQueue();
      expect(repository.sent, isEmpty, reason: 'aucun tour de quota en douce');
      expect(await store.read(), isNull);
    },
  );

  group('partir ou arrêter', () {
    test(
      'fil reconstruit pendant un tour : la question reste, le tour reprend',
      () async {
        final repository = FakeCoachRepository(threads: [summary])
          ..hangUntilCancelled = true;
        final container = containerWith(repository);
        container.listen(coachThreadProvider, (_, __) {});
        await container.read(coachThreadProvider.future);

        unawaited(
          container.read(coachThreadProvider.notifier).send('Demain ?'),
        );
        await pumpEventQueue();
        // Une carte touchée relit le fil (`ref.invalidate`) : l'instance du
        // Notifier survit, l'ancien tour est abandonné.
        container.invalidate(coachThreadProvider);
        final relu = await container.read(coachThreadProvider.future);
        await pumpEventQueue();

        expect((await store.read())?.content, 'Demain ?');
        expect(relu.live?.question, 'Demain ?');
        expect(
          container.read(coachThreadProvider).valueOrNull?.live,
          isNotNull,
        );
        expect(repository.cancelled, isEmpty);
        container.read(coachThreadProvider.notifier).stop();
        await pumpEventQueue();
      },
    );

    test(
      'page quittée : le serveur n’est PAS arrêté, la question reste à reprendre',
      () async {
        final repository = FakeCoachRepository()..hangUntilCancelled = true;
        final container = containerWith(repository);
        final ecoute = container.listen(coachThreadProvider, (_, __) {});
        await container.read(coachThreadProvider.future);

        final envoi = container
            .read(coachThreadProvider.notifier)
            .send('Demain ?');
        await pumpEventQueue();
        ecoute.close(); // l'écran se démonte : le fil autoDispose part
        await pumpEventQueue();

        expect(await envoi, isFalse);
        expect(repository.cancelled, isEmpty);
        expect((await store.read())?.content, 'Demain ?');
      },
    );

    test(
      '« Arrêter » : le serveur est prévenu, plus rien à reprendre',
      () async {
        final repository = FakeCoachRepository()..hangUntilCancelled = true;
        final container = containerWith(repository);
        container.listen(coachThreadProvider, (_, __) {});
        await container.read(coachThreadProvider.future);

        final envoi = container
            .read(coachThreadProvider.notifier)
            .send('Demain ?');
        await pumpEventQueue();
        container.read(coachThreadProvider.notifier).stop();

        expect(await envoi, isFalse);
        expect(repository.cancelled, repository.sentIds);
        expect(await store.read(), isNull);
      },
    );
  });
}
