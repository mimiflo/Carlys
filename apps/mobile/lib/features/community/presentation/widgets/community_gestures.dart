import 'package:flutter/material.dart';

import '../../domain/entities/community.dart';
import '../../domain/entities/community_moderation.dart';
import '../controllers/community_controllers.dart';
import '../controllers/community_moderation_controllers.dart';
import 'community_confirm_sheet.dart';
import 'community_feedback.dart';
import 'report_sheet.dart';

/// Les gestes de la communauté, du doigt jusqu'au serveur : confirmation
/// quand le geste retire quelqu'un, appel du contrôleur, puis un mot de
/// retour, ou l'échec dit vrai (voir [runCommunityGesture]).
///
/// Les cartes restent muettes (elles ne connaissent que des callbacks) :
/// c'est ici que vit l'enchaînement, et donc ici qu'on le teste.
class CommunityGestures {
  const CommunityGestures(this._actions, this._moderation);

  final CommunityActions _actions;
  final CommunityModerationActions _moderation;

  static const _reportSent =
      'Merci, ton signalement est envoyé. L’équipe Carlys s’en occupe.';

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

  // ── Se protéger ─────────────────────────────────────────────────────────

  /// Bloquer se confirme, puis la personne disparaît sans un mot pour elle :
  /// le retour ne l'accuse de rien, il dit seulement où revenir dessus.
  Future<void> blockFriend(BuildContext context, CommunityFriend friend) =>
      _block(context, userId: friend.id, name: friend.displayName);

  /// Bloquer depuis un MOT du fil, par son auteur.
  ///
  /// C'est le seul chemin qui reste quand l'auteur n'est plus un ami :
  /// retirer une amitié laisse les mots déjà reçus en place, et une carte
  /// d'ami disparue emporte son menu avec elle.
  Future<void> blockEncouragementAuthor(
    BuildContext context,
    Encouragement encouragement,
  ) => _block(
    context,
    userId: encouragement.fromUserId,
    name: encouragement.fromName,
  );

  /// Le blocage lui-même, quel que soit l'endroit d'où il part : même
  /// confirmation, même retour, un seul texte à maintenir.
  Future<void> _block(
    BuildContext context, {
    required String userId,
    required String name,
  }) async {
    final confirmed = await showCommunityConfirmSheet(
      context,
      title: 'Bloquer $name ?',
      message:
          '$name disparaît de tes amis, ne pourra plus t’écrire ni te '
          'redemander en ami, et n’en saura rien. Tu peux revenir dessus à '
          'tout moment depuis « Personnes bloquées ».',
      confirmLabel: 'Bloquer',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    await runCommunityGesture(context, () async {
      await _moderation.blockUser(userId);
      return 'Tu ne verras plus $name. Retour possible depuis '
          '« Personnes bloquées ».';
    });
  }

  /// Débloquer ne demande rien : rien n'est rétabli, donc rien à regretter.
  Future<void> unblock(BuildContext context, BlockedUser user) {
    return runCommunityGesture(context, () async {
      await _moderation.unblockUser(user.userId);
      return 'Blocage levé pour ${user.displayName}. L’amitié n’est pas '
          'rétablie : il faudra la redemander.';
    });
  }

  Future<void> reportFriend(
    BuildContext context,
    CommunityFriend friend,
  ) async {
    final report = await showReportSheet(
      context,
      title: 'Signaler ${friend.displayName}',
      subjectName: friend.displayName,
    );
    if (report == null || !context.mounted) {
      return;
    }
    await runCommunityGesture(context, () async {
      await _moderation.reportUser(friend.id, report);
      return _reportSent;
    });
  }

  Future<void> reportEncouragement(
    BuildContext context,
    Encouragement encouragement,
  ) async {
    final report = await showReportSheet(
      context,
      title: 'Signaler ce message',
      subjectName: encouragement.fromName,
    );
    if (report == null || !context.mounted) {
      return;
    }
    await runCommunityGesture(context, () async {
      await _moderation.reportEncouragement(encouragement, report);
      return _reportSent;
    });
  }

  /// Retirer un mot de SON fil ne se confirme pas : c'est son fil.
  Future<void> deleteEncouragement(
    BuildContext context,
    Encouragement encouragement,
  ) {
    return runCommunityGesture(context, () async {
      await _moderation.deleteEncouragement(encouragement.id);
      return 'Message retiré de ton fil.';
    });
  }
}
