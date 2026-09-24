import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';
import '../errors/app_exception.dart';
import '../logging/app_logger.dart';

/// Exécute un geste qui parle au SERVEUR et en rend compte dans une popup
/// (`AppNotices`) : le texte rendu par [gesture] en cas de succès (`null` :
/// rien à dire), sinon l'échec — en disant vrai, car hors ligne n'est pas une
/// panne. Le succès prend le ton « réussite », l'échec le ton « erreur ».
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
  var tone = AppNoticeTone.success;
  try {
    message = await gesture();
  } on AppException catch (exception) {
    logger.warning('Geste refusé par le serveur', error: exception);
    message = serverFailureMessage(exception);
    tone = AppNoticeTone.error;
  } on Exception catch (exception) {
    logger.warning('Geste en échec', error: exception);
    message = serverFailureMessage(null);
    tone = AppNoticeTone.error;
  }
  if (message == null || !context.mounted) {
    return;
  }
  AppNotices.of(context).show(message, tone: tone);
}

/// Même contrat que [runServerGesture], pour un geste qui écrit D'ABORD EN
/// LOCAL : il rend `true` si le geste a abouti, pour que l'appelant sache
/// s'il peut enchaîner (naviguer, refermer une feuille).
///
/// Pourquoi une seconde fonction. Une écriture locale échoue autrement qu'un
/// appel réseau : la règle « au plus une séance en cours » se défend par un
/// `StateError`, qui est une `Error` et non une `Exception` — `on Exception`
/// ne l'attrape donc PAS. C'est exactement ce qui faisait disparaître une
/// série saisie, sans message, sans navigation, sans trace : le bouton
/// semblait n'avoir pas répondu.
///
/// [echec] donne le mot juste pour CE geste-là : « la série n'a pas pu être
/// enregistrée » n'est pas « le repas n'a pas pu être ajouté ».
Future<bool> runLocalGesture(
  BuildContext context,
  Future<void> Function() gesture, {
  required String scope,
  required String echec,
}) async {
  try {
    await gesture();
    return true;
  } catch (erreur, trace) {
    // `catch` NU, et c'est le propos : `on Exception` laisserait filer les
    // `Error`, dont le `StateError` du domaine.
    AppLogger(
      scope,
    ).error('Geste local en échec', error: erreur, stackTrace: trace);
    if (context.mounted) {
      AppNotices.of(context).show(echec, tone: AppNoticeTone.error);
    }
    return false;
  }
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
