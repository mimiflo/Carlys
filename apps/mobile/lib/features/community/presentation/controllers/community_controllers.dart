import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/community_repository_impl.dart';
import '../../domain/entities/community.dart';

/// Encouragements reçus. Rafraîchis par invalidation après chaque action.
final encouragementsProvider =
    FutureProvider.autoDispose<List<Encouragement>>((ref) {
  return ref.watch(communityRepositoryProvider).encouragements();
});

final communityFriendsProvider =
    FutureProvider.autoDispose<List<CommunityFriend>>((ref) {
  return ref.watch(communityRepositoryProvider).friends();
});

final friendRequestsProvider =
    FutureProvider.autoDispose<List<FriendRequest>>((ref) {
  return ref.watch(communityRepositoryProvider).receivedRequests();
});

final communityChallengesProvider =
    FutureProvider.autoDispose<List<CommunityChallenge>>((ref) {
  return ref.watch(communityRepositoryProvider).challenges();
});

/// Ma préférence de partage — pilotée par le serveur, comme le reste.
final sharesProgressProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(communityRepositoryProvider).sharesProgress();
});

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

class CommunityActions {
  const CommunityActions(this._ref);

  final Ref _ref;

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

  Future<void> encourage(String friendId, String message) async {
    await _ref.read(communityRepositoryProvider).encourage(friendId, message);
    _ref.invalidate(encouragementsProvider);
  }

  /// Réponse opaque côté serveur : rien à lire, rien à invalider — les
  /// demandes ENVOYÉES ne sont jamais listées.
  Future<void> sendFriendRequest(String email) {
    return _ref.read(communityRepositoryProvider).sendFriendRequest(email);
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

  Future<void> setSharesProgress({required bool value}) async {
    await _ref
        .read(communityRepositoryProvider)
        .setSharesProgress(value: value);
    _ref.invalidate(sharesProgressProvider);
  }
}
