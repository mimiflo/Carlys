import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/community_repository_impl.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/community_moderation.dart';
import 'community_controllers.dart';

/// Personnes que j'ai bloquées. Rafraîchie par invalidation après chaque
/// blocage ou déblocage, comme les autres lectures de la communauté.
final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>((
  ref,
) {
  return ref.watch(communityRepositoryProvider).listBlocked();
});

/// Gestes de protection : chaque écriture invalide ce qu'elle change.
///
/// Permanent, pour la même raison que [communityActionsProvider] : lu au
/// build, rappelé dans des callbacks bien plus tard.
final communityModerationActionsProvider = Provider<CommunityModerationActions>(
  (ref) => CommunityModerationActions(ref),
);

class CommunityModerationActions {
  const CommunityModerationActions(this._ref);

  final Ref _ref;

  /// Bloquer retire l'amitié et les demandes des deux côtés, et le serveur
  /// cesse de servir les mots de cette personne : tout ce qui pouvait la
  /// montrer se rafraîchit, elle disparaît sans un mot.
  Future<void> blockUser(String userId) async {
    await _ref.read(communityRepositoryProvider).blockUser(userId);
    _ref
      ..invalidate(communityFriendsProvider)
      ..invalidate(friendRequestsProvider)
      ..invalidate(encouragementsProvider)
      ..invalidate(blockedUsersProvider);
  }

  /// Débloquer ne rétablit rien : seule la liste des blocages bouge.
  Future<void> unblockUser(String userId) async {
    await _ref.read(communityRepositoryProvider).unblockUser(userId);
    _ref.invalidate(blockedUsersProvider);
  }

  Future<void> deleteEncouragement(String encouragementId) async {
    await _ref
        .read(communityRepositoryProvider)
        .deleteEncouragement(encouragementId);
    _ref.invalidate(encouragementsProvider);
  }

  /// Un signalement ne change rien à l'écran : rien à invalider.
  Future<void> reportUser(String userId, CommunityReportDraft report) {
    return _ref.read(communityRepositoryProvider).reportUser(userId, report);
  }

  Future<void> reportEncouragement(
    Encouragement encouragement,
    CommunityReportDraft report,
  ) {
    return _ref
        .read(communityRepositoryProvider)
        .reportEncouragement(encouragement, report);
  }
}
