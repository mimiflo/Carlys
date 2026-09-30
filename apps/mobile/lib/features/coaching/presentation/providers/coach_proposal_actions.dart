import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/coach_repository_impl.dart';
import '../../data/repositories/coach_session_launcher.dart';
import '../../domain/entities/coach.dart';

/// Lance la séance proposée et signale l'acceptation au serveur.
///
/// L'ordre compte : la séance est écrite en local **d'abord**. Si la note au
/// serveur échoue, l'utilisateur s'entraîne quand même — c'est une statistique
/// qui manque, pas une séance perdue.
class CoachProposalActions {
  const CoachProposalActions(this._ref);

  final Ref _ref;

  Future<String> start(CoachSessionProposal proposal) async {
    // Une proposition DÉJÀ acceptée a déjà sa séance : le serveur nous dit
    // laquelle (`acceptedSessionId`), et l'appui suivant doit y ramener, pas
    // en créer une seconde. Sans ce garde-fou, rouvrir le fil et réappuyer
    // fabriquait une séance de plus à chaque fois — sitôt la précédente
    // terminée, puisque la règle « au plus une séance en cours » ne bloque
    // que pendant. L'historique se remplissait de séances jamais faites.
    final already = proposal.acceptedSessionId;
    if (already != null) {
      return already;
    }

    final sessionId = await _ref
        .read(coachSessionLauncherProvider)
        .start(proposal);

    try {
      await _ref
          .read(coachRepositoryProvider)
          .markProposalAccepted(proposalId: proposal.id, sessionId: sessionId);
    } on AppException {
      // Volontairement avalé : la séance existe, elle est en file de
      // synchronisation, et l'écran de séance s'ouvre. Rien à dire ici.
    }

    return sessionId;
  }
}

final coachProposalActionsProvider = Provider<CoachProposalActions>(
  CoachProposalActions.new,
);
