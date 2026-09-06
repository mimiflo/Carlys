import 'package:flutter/material.dart';

import '../../domain/entities/community.dart';
import '../controllers/community_controllers.dart';
import 'community_confirm_sheet.dart';
import 'community_feedback.dart';

/// Les gestes de la communauté, du doigt jusqu'au serveur : confirmation
/// quand le geste retire quelqu'un, appel du contrôleur, puis un mot de
/// retour, ou l'échec dit vrai (voir [runCommunityGesture]).
///
/// Les cartes restent muettes (elles ne connaissent que des callbacks) :
/// c'est ici que vit l'enchaînement, et donc ici qu'on le teste.
class CommunityGestures {
  const CommunityGestures(this._actions);

  final CommunityActions _actions;

  Future<void> respondToRequest(
    BuildContext context,
    FriendRequest request, {
    required bool accept,
  }) {
    return runCommunityGesture(context, () async {
      await _actions.respondToRequest(request.id, accept: accept);
      return null;
    });
  }

  Future<void> encourage(BuildContext context, CommunityFriend friend) {
    return runCommunityGesture(context, () async {
      await _actions.encourage(friend.id, 'Continue, ça paie !');
      return null;
    });
  }

  Future<void> toggleChallenge(
    BuildContext context,
    CommunityChallenge challenge,
  ) {
    return runCommunityGesture(context, () async {
      await _actions.toggleChallenge(challenge);
      return null;
    });
  }

  Future<void> setSharesProgress(BuildContext context, {required bool value}) {
    return runCommunityGesture(context, () async {
      await _actions.setSharesProgress(value: value);
      return null;
    });
  }

  /// Retirer un ami se confirme : l'amitié était acceptée des deux côtés.
  Future<void> removeFriend(
    BuildContext context,
    CommunityFriend friend,
  ) async {
    final name = friend.displayName;
    final confirmed = await showCommunityConfirmSheet(
      context,
      title: 'Retirer $name de tes amis ?',
      message:
          'Vous ne verrez plus vos progressions ni vos encouragements. '
          '$name pourra te redemander en ami.',
      confirmLabel: 'Retirer',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    await runCommunityGesture(context, () async {
      await _actions.removeFriend(friend.id);
      return '$name ne fait plus partie de tes amis.';
    });
  }
}
