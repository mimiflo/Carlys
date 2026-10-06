import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/account_bound_cache.dart';
import '../../../authentication/presentation/providers/keep_for_account.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/friend_challenge.dart';
import '../../domain/entities/league.dart';

/// Les lectures de la Communauté sont GARDÉES deux minutes ([keepForAccount]) :
/// passer d'un onglet à l'autre ne relance plus toutes leurs requêtes.
///
/// Encouragements reçus. Rafraîchis par invalidation après chaque action.
final encouragementsProvider = FutureProvider.autoDispose<List<Encouragement>>((
  ref,
) {
  return keepForAccount(
    ref,
    () => ref.watch(communityRepositoryProvider).encouragements(),
  );
});

final communityFriendsProvider =
    FutureProvider.autoDispose<List<CommunityFriend>>((ref) {
      return keepForAccount(
        ref,
        () => ref.watch(communityRepositoryProvider).friends(),
      );
    });

final friendRequestsProvider = FutureProvider.autoDispose<List<FriendRequest>>((
  ref,
) {
  return keepForAccount(
    ref,
    () => ref.watch(communityRepositoryProvider).receivedRequests(),
  );
});

final communityChallengesProvider =
    FutureProvider.autoDispose<List<CommunityChallenge>>((ref) {
      return keepForAccount(
        ref,
        () => ref.watch(communityRepositoryProvider).challenges(),
      );
    });

/// Mes défis entre amis : proposés et acceptés.
final friendChallengesProvider =
    FutureProvider.autoDispose<List<FriendChallenge>>((ref) {
      return keepForAccount(
        ref,
        () => ref.watch(communityRepositoryProvider).friendChallenges(),
      );
    });

/// Ma ligue de la semaine. Sans adhésion, le classement arrive VIDE : on
/// n'est classé qu'après avoir dit oui.
final leagueProvider = FutureProvider.autoDispose<League>((ref) {
  return keepForAccount(
    ref,
    () => ref.watch(communityRepositoryProvider).league(),
  );
});

/// Ma préférence de partage — pilotée par le serveur, comme le reste.
final sharesProgressProvider = FutureProvider.autoDispose<bool>((ref) {
  return keepForAccount(
    ref,
    () => ref.watch(communityRepositoryProvider).sharesProgress(),
  );
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
