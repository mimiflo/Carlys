import '../entities/community.dart';

/// Contrat de la communauté.
///
/// Toutes les listes sont TRIÉES par le dépôt (les écrans n'ordonnent pas),
/// et vides quand la fonctionnalité n'est pas disponible — jamais d'erreur
/// pour une absence : la communauté est un plus, pas une dépendance.
abstract interface class CommunityRepository {
  /// Encouragements reçus, du plus récent au plus ancien.
  Future<List<Encouragement>> encouragements();

  /// Amis, série la plus longue d'abord.
  Future<List<CommunityFriend>> friends();

  /// Défis en cours, échéance la plus proche d'abord.
  Future<List<CommunityChallenge>> challenges();

  /// Rejoint ou quitte un défi ; rend l'état à jour.
  Future<CommunityChallenge> toggleChallenge(String challengeId);

  /// Envoie un encouragement à un ami.
  Future<void> encourage(String friendId, String message);
}
