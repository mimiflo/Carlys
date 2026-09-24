/// OÙ MÈNE UNE NOTIFICATION touchée : l'écran qui répond à ce qu'elle
/// annonce.
///
/// Le serveur le dit dans les données du message (`destination`, et
/// `challengeId` pour un défi — contrat `PUSH_DESTINATIONS` de
/// `packages/api-contracts`). L'application ne suit jamais une adresse
/// brute venue du réseau : elle reconnaît une LISTE FERMÉE de destinations,
/// et tout le reste ouvre simplement l'application, là où elle était.
sealed class PushDestination {
  const PushDestination();

  /// La destination portée par les données d'un message, ou `null` si elle
  /// est absente, inconnue (serveur plus récent) ou mal formée.
  static PushDestination? fromData(Map<String, Object?> data) {
    return switch (data['destination']) {
      'community-friends' => const CommunityFriendsDestination(),
      'friend-challenge' => FriendChallengeDestination.parse(
        data['challengeId'],
      ),
      _ => null,
    };
  }
}

/// L'onglet Amis de la Communauté : une demande d'ami, une acceptation, un
/// encouragement.
final class CommunityFriendsDestination extends PushDestination {
  const CommunityFriendsDestination();

  @override
  bool operator ==(Object other) => other is CommunityFriendsDestination;

  @override
  int get hashCode => (CommunityFriendsDestination).hashCode;
}

/// L'écran d'un défi entre amis : l'invitation qu'on vient de recevoir.
final class FriendChallengeDestination extends PushDestination {
  const FriendChallengeDestination(this.challengeId);

  /// Un identifiant de défi est un UUID créé sur l'appareil du créateur :
  /// rien d'autre ne se glisse dans une adresse de l'application.
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  static FriendChallengeDestination? parse(Object? challengeId) =>
      challengeId is String && _uuid.hasMatch(challengeId)
      ? FriendChallengeDestination(challengeId)
      : null;

  final String challengeId;

  @override
  bool operator ==(Object other) =>
      other is FriendChallengeDestination && other.challengeId == challengeId;

  @override
  int get hashCode => challengeId.hashCode;
}
