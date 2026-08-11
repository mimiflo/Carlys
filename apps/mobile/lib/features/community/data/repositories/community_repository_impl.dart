import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/community.dart';
import '../../domain/repositories/community_repository.dart';

/// Communauté SANS serveur : tout est vide, rien n'échoue.
///
/// L'API de la communauté n'existe pas encore côté serveur — c'est la
/// prochaine tranche verticale. En attendant, ce dépôt rend des listes
/// vides : les écrans affichent leurs états vides, l'accueil masque sa carte
/// communauté, et RIEN n'est inventé. Quand l'API arrivera, ce fichier
/// deviendra l'implémentation Dio, sans toucher ni au domaine ni aux écrans.
class UnbackedCommunityRepository implements CommunityRepository {
  const UnbackedCommunityRepository();

  @override
  Future<List<Encouragement>> encouragements() async => const [];

  @override
  Future<List<CommunityFriend>> friends() async => const [];

  @override
  Future<List<CommunityChallenge>> challenges() async => const [];

  @override
  Future<CommunityChallenge> toggleChallenge(String challengeId) {
    throw StateError('La communauté n’a pas encore de serveur.');
  }

  @override
  Future<void> encourage(String friendId, String message) {
    throw StateError('La communauté n’a pas encore de serveur.');
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return const UnbackedCommunityRepository();
});
