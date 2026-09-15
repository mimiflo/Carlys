import 'package:flutter/material.dart';

import '../errors/app_exception.dart';
import '../logging/app_logger.dart';

/// Exécute un geste qui parle au SERVEUR et en rend compte dans la barre de
/// message : le texte rendu par [gesture] en cas de succès (`null` : rien à
/// dire), sinon l'échec — en disant vrai, car hors ligne n'est pas une panne.
///
/// POURQUOI CETTE FONCTION EST AU CŒUR ET PLUS DANS `community`. Elle y était
/// née, et la règle qu'elle porte ne l'est pas : tout geste qui part sur le
/// réseau doit dire ce qu'il advient de lui. Trois écrans ne le faisaient
/// pas, et chacun de la même façon — la feuille se refermait, la liste ne
/// bougeait pas, et rien n'expliquait pourquoi :
///
/// - déconnecter un appareil, un échec laissait l'appareil listé ;
/// - ajouter un repas, la feuille se refermait sur un journal inchangé ;
/// - supprimer un repas, la ligne restait, sans un mot.
///
/// Recopier le filet dans chacun aurait donné trois formulations qui
/// divergent ; il vaut mieux qu'ils partagent la même.
///
/// Le [scope] ne sert qu'au journal technique : il n'atteint jamais l'écran.
Future<void> runServerGesture(
  BuildContext context,
  Future<String?> Function() gesture, {
  required String scope,
}) async {
  final logger = AppLogger(scope);
  String? message;
  try {
    message = await gesture();
  } on AppException catch (exception) {
    logger.warning('Geste refusé par le serveur', error: exception);
    message = serverFailureMessage(exception);
  } on Exception catch (exception) {
    logger.warning('Geste en échec', error: exception);
    message = serverFailureMessage(null);
  }
  if (message == null || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Le mot juste pour un geste qui n'a pas abouti, hors ligne ou pas.
///
/// La distinction compte : « réessaie une fois connecté » est une consigne
/// que la personne peut suivre, « ça n'a pas fonctionné » n'en est pas une.
String serverFailureMessage(AppException? exception) {
  return exception is NetworkException
      ? 'Hors connexion : ce geste a besoin du réseau. Réessaie une fois '
            'connecté.'
      : 'Ça n’a pas fonctionné. Réessaie dans un instant.';
}
