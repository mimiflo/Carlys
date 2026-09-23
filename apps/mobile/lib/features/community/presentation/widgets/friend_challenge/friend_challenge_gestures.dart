import 'package:flutter/material.dart';

import '../../../domain/entities/friend_challenge.dart';
import '../../controllers/community_controllers.dart';
import '../../controllers/community_moderation_controllers.dart';
import '../community_confirm_sheet.dart';
import '../community_feedback.dart';
import '../report_sheet.dart';

/// Les gestes d'un défi ENTRE AMIS, du doigt jusqu'au serveur : accepter,
/// refuser ou quitter, signaler son message.
///
/// Sortis de `CommunityGestures` quand l'écran de détail est arrivé : la
/// carte de l'onglet Défis et l'écran les partagent, et un seul endroit
/// décide de la confirmation et des mots de retour.
class FriendChallengeGestures {
  const FriendChallengeGestures(this._actions, this._moderation);

  final CommunityActions _actions;
  final CommunityModerationActions _moderation;

  /// Accepter : on entre au classement, à zéro. Le geste DIT qu'il a
  /// abouti — la carte change d'état, mais pas de place dans la liste.
  Future<void> accept(BuildContext context, FriendChallenge challenge) {
    return runCommunityGesture(context, () async {
      await _actions.acceptFriendChallenge(challenge.id);
      return 'Tu es dans le défi « ${challenge.title} ».';
    });
  }

  /// Refuser ou quitter : dans les deux cas on sort du classement, et le
  /// défi quitte la liste. Quitter un défi DÉJÀ commencé se confirme ;
  /// refuser une invitation, non : c'est une réponse, pas un abandon.
  ///
  /// [onLeft] suit un départ ABOUTI — l'écran de détail s'y referme, puisque
  /// le serveur ne le montre plus qu'à ses membres actifs.
  Future<void> leave(
    BuildContext context,
    FriendChallenge challenge, {
    VoidCallback? onLeft,
  }) async {
    if (!challenge.isPending) {
      final confirme = await showCommunityConfirmSheet(
        context,
        title: 'Quitter « ${challenge.title} » ?',
        message:
            'Tu sors du classement. Ce que tu as fait pendant le défi ne '
            'comptera plus pour lui.',
        confirmLabel: 'Quitter',
      );
      if (!confirme || !context.mounted) {
        return;
      }
    }
    await runCommunityGesture(context, () async {
      await _actions.declineFriendChallenge(challenge.id);
      onLeft?.call();
      return null;
    });
  }

  /// Signaler le titre et le message du défi, sous le nom de son créateur :
  /// c'est lui qui les a écrits. Le défi n'est pas quitté pour autant.
  Future<void> report(BuildContext context, FriendChallenge challenge) async {
    final report = await showReportSheet(
      context,
      title: 'Signaler ce défi',
      subjectName: challenge.creatorDisplayName,
    );
    if (report == null || !context.mounted) {
      return;
    }
    await runCommunityGesture(context, () async {
      await _moderation.reportFriendChallenge(challenge, report);
      return 'Merci, ton signalement est envoyé. L’équipe Carlys s’en occupe.';
    });
  }
}
