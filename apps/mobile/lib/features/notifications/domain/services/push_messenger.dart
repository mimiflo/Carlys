import '../../../../app/environment/app_environment.dart';

/// Frontière UNIQUE avec Firebase Messaging.
///
/// Toute la logique d'enregistrement (démarrage conditionnel, envoi du jeton
/// au serveur, rafraîchissement, oubli à la déconnexion) se teste contre un
/// faux qui implémente ce port : aucun test ne touche un plugin de
/// plateforme, et changer de fournisseur ne toucherait qu'un fichier.
abstract class PushMessenger {
  /// Initialise le SDK avec [options] puis demande la permission de notifier.
  ///
  /// Rend le jeton d'enregistrement de l'appareil, ou `null` si la
  /// permission est refusée — refuser les notifications est un choix
  /// respecté, pas une erreur.
  Future<String?> obtainToken(FirebasePushOptions options);

  /// Jetons régénérés par FCM au fil de la vie de l'application : chacun
  /// doit être ré-enregistré côté serveur pour rester joignable.
  Stream<String> get onTokenRefresh;

  /// Invalide le jeton local (déconnexion) : l'appareil ne recevra plus rien
  /// même si une ligne serveur survivait quelque part.
  Future<void> deleteToken();
}
