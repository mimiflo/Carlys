import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// À QUI appartiennent les données locales de cet appareil.
///
/// Écrit à chaque entrée dans un compte (connexion, inscription,
/// restauration d'une session au démarrage), effacé par la purge : tant
/// qu'il est renseigné, la base Drift et les préférences du compte sont
/// celles de CE compte-là.
///
/// C'est ce marqueur, et non la file de synchronisation, qui décide de la
/// purge à la connexion. `sync_operations.ownerUserId` ne dit qui possède
/// l'appareil que tant qu'il reste une opération à envoyer : sur un compte
/// entièrement synchronisé — le cas le plus fréquent — la file est vide et
/// laisserait l'historique complet du précédent au suivant. Une préférence
/// écrite à chaque entrée, elle, survit à une file vidée.
///
/// L'identifiant stocké est le claim `sub` du jeton d'accès : exactement
/// celui sous lequel le serveur attribue les opérations, et lisible hors
/// ligne. Ce n'est pas un secret (les jetons, eux, vivent dans le stockage
/// sécurisé) : SharedPreferences convient.
class LocalAccountOwner {
  const LocalAccountOwner();

  static const String key = 'compte.proprietaire_local';

  /// `null` quand l'appareil ne porte les données d'aucun compte connu.
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  Future<void> write(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, userId);
  }
}

final localAccountOwnerProvider = Provider<LocalAccountOwner>(
  (ref) => const LocalAccountOwner(),
);
