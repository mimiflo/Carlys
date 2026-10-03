import '../../../../core/errors/app_exception.dart';
import '../entities/coach.dart';

/// Le plus long qu'on attende une réponse que le serveur écrit encore : sa
/// file puis sa génération (`COACH_QUEUE_TIMEOUT_MS` +
/// `COACH_REQUEST_TIMEOUT_MS`, 12,3 min par défaut), avec de la marge. Si
/// l'exploitation relève ces deux réglages, relever celui-ci d'autant.
const coachReplyPatience = Duration(minutes: 13);

/// La réponse du coach à une question, même s'il l'écrit encore ailleurs.
///
/// Le serveur finit toute réponse commencée — page quittée, appli fermée —
/// et l'archive ; renvoyer la MÊME question (même identifiant) la rend,
/// sans nouveau tour. Tant qu'il l'écrit encore, il répond 409 (par HTTP
/// comme par le flux) : on attend [every], puis on redemande, au plus
/// [giveUpAfter] ([coachReplyPatience]).
/// [stopped] dit que la personne a arrêté, ou est partie : on cesse alors de
/// redemander.
///
/// ponytail: tout 409 attend, y compris la collision d'identifiant — elle
/// n'arrive que sur un défaut de l'appli (identifiant tiré à neuf à chaque
/// nouveau texte) ; un code d'erreur distinct le jour où elle arriverait.
Future<CoachReply> awaitCoachReply(
  Future<CoachReply> Function() send, {
  required bool Function() stopped,
  Duration every = const Duration(seconds: 3),
  Duration giveUpAfter = coachReplyPatience,
}) async {
  for (var waited = Duration.zero; ; waited += every) {
    try {
      return await send();
    } on AppException catch (exception) {
      final stillWriting = exception.statusCode == 409;
      if (!stillWriting || stopped() || waited >= giveUpAfter) rethrow;
    }
    await Future<void>.delayed(every);
    if (stopped()) throw const UnknownException('Attente arrêtée');
  }
}
