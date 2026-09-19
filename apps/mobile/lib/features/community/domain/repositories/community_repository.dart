import '../entities/community.dart';
import '../entities/community_moderation.dart';
import '../entities/friend_challenge.dart';

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

  /// Mon code ami, sous forme CANONIQUE (8 caractères) — l'affichage
  /// XXXX-XXXX et le QR se dérivent avec `friend_code.dart`.
  Future<String> myFriendCode();

  /// Nom du porteur d'un code (tapé ou scanné), ou `null` si personne ne
  /// le porte. Un code se partage volontairement : le confirmer par un nom
  /// n'énumère rien.
  Future<String?> lookupFriendCode(String code);

  /// Demande quelqu'un en ami par son code. Même opacité que par e-mail.
  Future<void> sendFriendRequestByCode(String code);

  /// Accepte ou refuse une demande reçue.
  Future<void> respondToRequest(String requestId, {required bool accept});

  /// Retire un ami (idempotent côté serveur). L'autre n'est pas prévenu et
  /// pourra redemander : rien d'irréversible, mais rien de silencieux non
  /// plus, l'écran confirme avant.
  Future<void> removeFriend(String userId);

  /// Défis en cours, échéance la plus proche d'abord.
  Future<List<CommunityChallenge>> challenges();

  /// Rejoint un défi (idempotent) ; rend l'état à jour.
  Future<CommunityChallenge> joinChallenge(String challengeId);

  /// Quitte un défi (idempotent) ; rend l'état à jour.
  Future<CommunityChallenge> leaveChallenge(String challengeId);

  /// Envoie un encouragement à un ami accepté.
  Future<void> encourage(String friendId, String message);

  /// Enregistre une réponse de quiz de l'Academy. Idempotent par
  /// (leçon, jour local) : seule une PREMIÈRE réponse juste contribue aux
  /// défis culturels rejoints. Le choix retenu part avec, pour que la
  /// progression se relise sur un autre appareil.
  Future<void> reportQuizAnswer({
    required String lessonId,
    required String answeredOn,
    required bool correct,
    required int choiceIndex,
  });

  /// Les réponses déjà enregistrées côté serveur : identifiant de leçon
  /// vers l'index du choix retenu, `null` quand une réponse d'avant la
  /// migration n'a pas emporté le choix (on sait « abordée », pas
  /// « quoi »). Une entrée par leçon, la PREMIÈRE réponse fait foi — la
  /// même règle que le magasin local.
  Future<Map<String, int?>> fetchQuizAnswers();

  /// Ma préférence : partager (ou non) ma progression avec mes amis.
  Future<bool> sharesProgress();

  Future<void> setSharesProgress({required bool value});

  // ── Se protéger ─────────────────────────────────────────────────────────

  /// Bloque quelqu'un (idempotent). Le serveur retire l'amitié et les
  /// demandes en attente dans les deux sens ; l'autre n'est jamais prévenu.
  Future<void> blockUser(String userId);

  /// Lève un blocage (idempotent). Ne rétablit ni amitié ni demande.
  Future<void> unblockUser(String userId);

  /// Personnes que j'ai bloquées, dernier blocage d'abord.
  Future<List<BlockedUser>> listBlocked();

  /// Signale une personne. Un signalement OUVERT identique n'est pas
  /// dupliqué par le serveur : rejouer l'envoi est sans conséquence.
  Future<void> reportUser(String userId, CommunityReportDraft report);

  /// Signale un encouragement précis, sous le nom de son auteur.
  Future<void> reportEncouragement(
    Encouragement encouragement,
    CommunityReportDraft report,
  );

  /// Retire un encouragement de mon fil (rejouable et opaque côté serveur).
  Future<void> deleteEncouragement(String encouragementId);

  // ── Défis entre amis ──────────────────────────────────────────────────

  /// Mes défis entre amis : ceux qu'on m'a proposés et ceux que j'ai
  /// acceptés. Les refusés et les quittés n'y sont plus — ce sont des
  /// décisions prises, pas des choses à revoir.
  Future<List<FriendChallenge>> friendChallenges();

  /// Lance un défi à ses amis. L'identifiant naît sur l'appareil : rejouer
  /// après une coupure ne pose pas un second défi.
  Future<FriendChallenge> createFriendChallenge(
    String id,
    NewFriendChallenge challenge,
  );

  /// Accepte une invitation : on entre au classement, à zéro.
  Future<FriendChallenge> acceptFriendChallenge(String challengeId);

  /// Refuse une invitation, ou quitte un défi commencé. Dans les deux cas,
  /// on sort du classement — contrairement à un défi collectif, dont la
  /// contribution reste acquise au groupe.
  Future<void> declineFriendChallenge(String challengeId);
}
