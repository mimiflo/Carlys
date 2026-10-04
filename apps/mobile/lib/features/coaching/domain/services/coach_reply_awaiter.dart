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
/// comme par le flux) : on attend [_every], puis on redemande, au plus
/// [giveUpAfter] ([coachReplyPatience]).
/// [stopped] dit que la personne a arrêté, ou est partie : on cesse alors de
/// redemander.
///
/// Seul ce 409-là attend. La collision d'identifiant (même identifiant,
/// autre texte : un défaut de l'appli) porte le code `IDENTIFIER_CONFLICT`
/// et ne passera jamais : elle remonte tout de suite. Un serveur d'avant ce
/// code rend `CONFLICT` pour les deux : on attend alors, comme avant.
const Duration _every = Duration(seconds: 3);

Future<CoachReply> awaitCoachReply(
  Future<CoachReply> Function() send, {
  required bool Function() stopped,
  Duration giveUpAfter = coachReplyPatience,
}) async {
  for (var waited = Duration.zero; ; waited += _every) {
    try {
      return await send();
    } on AppException catch (exception) {
      final stillWriting =
          exception.statusCode == 409 &&
          exception.code != 'IDENTIFIER_CONFLICT';
      if (!stillWriting || stopped() || waited >= giveUpAfter) rethrow;
    }
    await Future<void>.delayed(_every);
    if (stopped()) throw const UnknownException('Attente arrêtée');
  }
}
