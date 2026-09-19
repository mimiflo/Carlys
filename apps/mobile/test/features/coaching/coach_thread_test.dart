import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_session_launcher.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/controllers/coach_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_coach_repository.dart';

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
  ProviderContainer containerWith(FakeCoachRepository repository) {
    final container = ProviderContainer(
      overrides: [coachRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

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
