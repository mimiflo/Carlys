/// UN défi entre amis, lu seul : son classement, ses invités, son message.
///
/// La liste (`friendChallengesProvider`) sert la carte de l'onglet Défis ;
/// l'écran de détail relit le défi par son identifiant, pour montrer ce qui
/// a pu bouger depuis (une séance d'un ami, une invitation acceptée) sans
/// relire toute la liste. Dérivé et sans état propre : `providers/`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/community_repository_impl.dart';
import '../../domain/entities/friend_challenge.dart';

final friendChallengeDetailProvider = FutureProvider.autoDispose
    .family<FriendChallenge, String>((ref, challengeId) {
      return ref
          .watch(communityRepositoryProvider)
          .friendChallenge(challengeId);
    });
