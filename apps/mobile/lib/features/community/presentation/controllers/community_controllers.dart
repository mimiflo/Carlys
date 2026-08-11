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

final communityChallengesProvider =
    FutureProvider.autoDispose<List<CommunityChallenge>>((ref) {
  return ref.watch(communityRepositoryProvider).challenges();
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

  Future<void> toggleChallenge(String challengeId) async {
    await _ref.read(communityRepositoryProvider).toggleChallenge(challengeId);
    _ref.invalidate(communityChallengesProvider);
  }

  Future<void> encourage(String friendId, String message) async {
    await _ref.read(communityRepositoryProvider).encourage(friendId, message);
    _ref.invalidate(encouragementsProvider);
  }
}
