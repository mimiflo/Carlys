/// Compteur d'hydratation du jour — contrat.
///
/// Vit ici, dans `domain/repositories/`, comme tous les autres contrats du
/// dépôt. Il a longtemps été déclaré au milieu de `presentation/controllers/`,
/// avec son implémentation Drift, et ce rangement a coûté un bogue : une
/// implémentation posée à côté de son provider se relit comme du câblage, et
/// personne n'a vu qu'elle capturait l'horloge. Voir
/// `data/repositories/local_water_store.dart`.
abstract interface class WaterStore {
  /// Millilitres bus AUJOURD'HUI, le flux suivant le jour réel.
  ///
  /// « Aujourd'hui » se réévalue : le flux ne se contente pas de lire le jour
  /// une fois pour toutes à l'abonnement, il bascule sur le jour suivant au
  /// passage de minuit. L'écran l'annonce — « remis à zéro chaque nuit » — et
  /// l'accueil reste monté toute la nuit.
  Stream<int> watchToday();

  /// Ajoute (ou retire, si négatif) au total du jour, et rend le nouveau
  /// total. Borné à zéro : on ne « dé-boit » pas.
  Future<int> addToday(int milliliters);
}
