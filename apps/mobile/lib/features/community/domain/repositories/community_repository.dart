import '../entities/community.dart';

/// Contrat de la communauté.
///
/// Toutes les listes sont TRIÉES par le dépôt (les écrans n'ordonnent pas).
/// Les règles de confidentialité vivent CÔTÉ SERVEUR : le dépôt ne fait que
/// transporter ce que le serveur a accepté de dire.
abstract interface class CommunityRepository {
  /// Encouragements reçus, du plus récent au plus ancien.
  Future<List<Encouragement>> encouragements();

  /// Amis acceptés, série la plus longue d'abord.
  Future<List<CommunityFriend>> friends();

  /// Demandes d'ami REÇUES, en attente.
  Future<List<FriendRequest>> receivedRequests();

  /// Demande quelqu'un en ami par e-mail EXACT. La réponse est opaque :
  /// elle aboutit toujours, qu'un compte existe ou non.
  Future<void> sendFriendRequest(String email);

  /// Accepte ou refuse une demande reçue.
  Future<void> respondToRequest(String requestId, {required bool accept});

  /// Défis en cours, échéance la plus proche d'abord.
  Future<List<CommunityChallenge>> challenges();

  /// Rejoint un défi (idempotent) ; rend l'état à jour.
  Future<CommunityChallenge> joinChallenge(String challengeId);

  /// Quitte un défi (idempotent) ; rend l'état à jour.
  Future<CommunityChallenge> leaveChallenge(String challengeId);

  /// Envoie un encouragement à un ami accepté.
  Future<void> encourage(String friendId, String message);

  /// Ma préférence : partager (ou non) ma progression avec mes amis.
  Future<bool> sharesProgress();

  Future<void> setSharesProgress({required bool value});
}
