import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/utilities/creation_identity.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../authentication/presentation/controllers/account_bound_cache.dart';

import '../../data/repositories/community_repository_impl.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/friend_challenge.dart';
import '../../domain/entities/league.dart';
import '../providers/friend_challenge_detail_providers.dart';

/// Encouragements reçus. Rafraîchis par invalidation après chaque action.
final encouragementsProvider = FutureProvider.autoDispose<List<Encouragement>>((
  ref,
) {
  return ref.watch(communityRepositoryProvider).encouragements();
});

final communityFriendsProvider =
    FutureProvider.autoDispose<List<CommunityFriend>>((ref) {
      return ref.watch(communityRepositoryProvider).friends();
    });

final friendRequestsProvider = FutureProvider.autoDispose<List<FriendRequest>>((
  ref,
) {
  return ref.watch(communityRepositoryProvider).receivedRequests();
});

final communityChallengesProvider =
    FutureProvider.autoDispose<List<CommunityChallenge>>((ref) {
      return ref.watch(communityRepositoryProvider).challenges();
    });

/// Mes défis entre amis : proposés et acceptés.
final friendChallengesProvider =
    FutureProvider.autoDispose<List<FriendChallenge>>((ref) {
      return ref.watch(communityRepositoryProvider).friendChallenges();
    });

/// Ma ligue de la semaine. Sans adhésion, le classement arrive VIDE : on
/// n'est classé qu'après avoir dit oui.
final leagueProvider = FutureProvider.autoDispose<League>((ref) {
  return ref.watch(communityRepositoryProvider).league();
});

/// Ma préférence de partage — pilotée par le serveur, comme le reste.
final sharesProgressProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(communityRepositoryProvider).sharesProgress();
});

/// Mon code ami (forme canonique). Un code est attribué à VIE : pas
/// d'auto-dispose, il ne changera pas sous les pieds de la feuille d'ajout.
/// Cache de compte : le code du compte parti ne se montre pas au suivant.
final myFriendCodeProvider = accountBoundCache<String>(
  (ref) => ref.watch(communityRepositoryProvider).myFriendCode(),
  none: '',
);

/// Le dernier encouragement reçu — la « petite notif » de l'accueil.
/// `null` tant qu'il n'y a rien à montrer : l'accueil masque alors sa carte.
final latestEncouragementProvider = Provider.autoDispose<Encouragement?>((ref) {
  final feed = ref.watch(encouragementsProvider).valueOrNull;
  return (feed == null || feed.isEmpty) ? null : feed.first;
});

/// Actions de la communauté : chaque écriture invalide les lectures.
///
/// PAS d'autoDispose ici : l'objet est lu (`ref.read`) au build puis rappelé
/// dans des callbacks bien plus tard. Un élément autoDispose jamais écouté
/// survit AUJOURD'HUI par accident d'implémentation Riverpod — un provider
/// permanent rend la durée de vie du `Ref` capturé garantie, pas fortuite.
final communityActionsProvider = Provider<CommunityActions>((ref) {
  return CommunityActions(ref);
});

/// L'identifiant du défi entre amis en cours de création, et son brouillon
/// tant que l'envoi n'a pas abouti. Appartient au COMPTE : la purge locale le
/// renouvelle (`LocalAccountPurge.accountOwnedProviders`).
final friendChallengeCreationProvider =
    Provider<CreationIdentity<NewFriendChallenge>>(
      (ref) => CreationIdentity<NewFriendChallenge>(),
    );

class CommunityActions {
  CommunityActions(this._ref);

  static const _logger = AppLogger('CommunityActions');

  final Ref _ref;

  /// Les amis dont l'encouragement est PARTI sans être encore acquitté.
  ///
  /// Rien ne bougeait à l'écran après un envoi (le fil ne sert que les mots
  /// REÇUS) : un second appui, réflexe naturel devant un bouton qui semble
  /// n'avoir rien fait, expédiait un second message. Le provider n'est pas
  /// `autoDispose`, cet ensemble vit donc aussi longtemps que l'application.
  final Set<String> _encouraging = <String>{};

  /// Rapporte une réponse de quiz aux défis culturels — SANS jamais gêner le
  /// quiz : l'Academy fonctionne hors ligne, l'échec est journalisé et la
  /// contribution est simplement perdue (la barre est collective, pas
  /// comptable).
  Future<void> reportQuizAnswer({
    required String lessonId,
    required bool correct,
    required int choiceIndex,
  }) async {
    try {
      await _ref
          .read(communityRepositoryProvider)
          .reportQuizAnswer(
            lessonId: lessonId,
            answeredOn: formatDayKey(DateTime.now()),
            correct: correct,
            choiceIndex: choiceIndex,
          );
    } on Exception catch (exception) {
      _logger.warning('Réponse de quiz non rapportée : $exception');
    }
  }

  /// Rejoint ou quitte selon l'état COURANT de la carte.
  Future<void> toggleChallenge(CommunityChallenge challenge) async {
    final repository = _ref.read(communityRepositoryProvider);
    if (challenge.joined) {
      await repository.leaveChallenge(challenge.id);
    } else {
      await repository.joinChallenge(challenge.id);
    }
    _ref.invalidate(communityChallengesProvider);
  }

  /// Lance un défi à ses amis. L'identifiant naît sur l'appareil, et
  /// SURVIT à l'échec : relancer le même brouillon après une réponse perdue
  /// rejoue le même identifiant, et le serveur retombe sur le défi déjà
  /// créé au lieu d'en poser un second (voir `CreationIdentity`).
  Future<void> createFriendChallenge(NewFriendChallenge challenge) async {
    final creation = _ref.read(friendChallengeCreationProvider);
    await _ref
        .read(communityRepositoryProvider)
        .createFriendChallenge(creation.idFor(challenge), challenge);
    creation.settle();
    _ref.invalidate(friendChallengesProvider);
  }

  /// Le brouillon du dernier défi dont l'envoi n'a pas abouti : la feuille
  /// s'y rouvre, pour ne pas faire tout ressaisir.
  NewFriendChallenge? get pendingFriendChallenge =>
      _ref.read(friendChallengeCreationProvider).pendingDraft;

  /// Accepte une invitation : on entre au classement, à zéro.
  Future<void> acceptFriendChallenge(String challengeId) async {
    await _ref
        .read(communityRepositoryProvider)
        .acceptFriendChallenge(challengeId);
    _ref
      ..invalidate(friendChallengesProvider)
      ..invalidate(friendChallengeDetailProvider(challengeId));
  }

  /// Refuse une invitation, ou quitte un défi commencé.
  Future<void> declineFriendChallenge(String challengeId) async {
    await _ref
        .read(communityRepositoryProvider)
        .declineFriendChallenge(challengeId);
    _ref
      ..invalidate(friendChallengesProvider)
      ..invalidate(friendChallengeDetailProvider(challengeId));
  }

  /// Encourage un ami. Rend `false` si un envoi est DÉJÀ en route vers lui —
  /// l'appelant sait alors qu'il n'a rien de neuf à annoncer.
  ///
  /// Rien n'est invalidé : encourager quelqu'un n'ajoute rien à son propre
  /// fil, puisque `/feed` ne sert que les mots REÇUS. L'invalidation qui
  /// suivait relançait un appel réseau, sur l'écran le plus fréquenté de la
  /// communauté, pour recevoir exactement la même liste.
  Future<bool> encourage(String friendId, String message) async {
    if (!_encouraging.add(friendId)) {
      return false;
    }
    try {
      await _ref.read(communityRepositoryProvider).encourage(friendId, message);
      return true;
    } finally {
      _encouraging.remove(friendId);
    }
  }

  /// Réponse opaque côté serveur : rien à lire, rien à invalider — les
  /// demandes ENVOYÉES ne sont jamais listées.
  Future<void> sendFriendRequest(String email) {
    return _ref.read(communityRepositoryProvider).sendFriendRequest(email);
  }

  /// Demande d'ami par code (tapé ou scanné). Rend le NOM du porteur quand
  /// le code correspond à un compte, `null` sinon — donner un code, c'est
  /// se désigner : le confirmer par un nom n'énumère rien, et « Demande
  /// envoyée à Sarah » vaut mieux qu'un message évasif.
  Future<String?> sendFriendRequestByCode(String code) async {
    final repository = _ref.read(communityRepositoryProvider);
    final displayName = await repository.lookupFriendCode(code);
    if (displayName == null) {
      return null;
    }
    await repository.sendFriendRequestByCode(code);
    return displayName;
  }

  Future<void> respondToRequest(
    String requestId, {
    required bool accept,
  }) async {
    await _ref
        .read(communityRepositoryProvider)
        .respondToRequest(requestId, accept: accept);
    _ref.invalidate(friendRequestsProvider);
    if (accept) {
      _ref.invalidate(communityFriendsProvider);
    }
  }

  /// Retire un ami : la liste se rafraîchit, le fil ne bouge pas (les mots
  /// déjà reçus restent lisibles, c'est le serveur qui décide du reste).
  Future<void> removeFriend(String userId) async {
    await _ref.read(communityRepositoryProvider).removeFriend(userId);
    _ref.invalidate(communityFriendsProvider);
  }

  /// Entre dans la ligue, ou en sort. Le geste EST le consentement, et il
  /// est distinct du partage de progression entre amis : celui-là n'a jamais
  /// promis de montrer un nom et un score à dix-neuf inconnus.
  Future<void> setLeagueJoined({required bool joined}) async {
    await _ref.read(communityRepositoryProvider).setLeagueJoined(joined);
    _ref.invalidate(leagueProvider);
  }

  Future<void> setSharesProgress({required bool value}) async {
    await _ref
        .read(communityRepositoryProvider)
        .setSharesProgress(value: value);
    _ref.invalidate(sharesProgressProvider);
  }
}
