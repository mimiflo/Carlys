import '../../../../core/errors/app_exception.dart';

/// Texte utilisateur d'un refus du serveur, ou `null` quand l'écran le dit
/// déjà (hors ligne : le composeur change d'état, pas de second message).
///
/// Extrait du contrôleur du fil : c'est une table, pas un comportement.
String? coachNoticeFor(AppException exception) {
  if (exception is NetworkException) return null;
  if (exception is ServerException && exception.code == 'SERVICE_BUSY') {
    // Debout mais saturé : ta question est restée dans le champ.
    return 'Le coach est très sollicité en ce moment. '
        'Réessaie dans un instant.';
  }
  // Même identifiant, autre texte : un défaut de l'appli, que réessayer ne
  // corrigera pas. Rien ne dit d'attendre.
  if (exception.code == 'IDENTIFIER_CONFLICT') {
    return 'Le coach n’a pas pu répondre.';
  }
  // Un 409 arrive en ValidationException par HTTP, en ServerException par
  // le flux : c'est le même refus.
  if (exception is ServerException || exception.statusCode == 409) {
    return switch (exception.statusCode) {
      // Le serveur dit lequel : plafond du jour, trop de messages dans la
      // minute, ou une réponse déjà en cours — ses messages sont écrits
      // pour la personne.
      429 when exception.fromApi => exception.message,
      429 =>
        'Tu as atteint le nombre de messages du jour. '
            'Le coach revient demain.',
      // La même question part encore : sa réponse s'écrit toujours côté
      // serveur (flux coupé puis renvoyé). Elle sera là au prochain envoi.
      409 => 'Le coach termine sa réponse. Réessaie dans un instant.',
      503 => 'Le coach est momentanément indisponible.',
      _ => 'Le coach n’a pas pu répondre. Réessaie dans un instant.',
    };
  }
  return 'Le coach n’a pas pu répondre. Réessaie dans un instant.';
}
