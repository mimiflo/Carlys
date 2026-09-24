import 'package:flutter/widgets.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';
import '../controllers/community_controllers.dart';
import 'add_friend_sheet.dart';
import 'community_feedback.dart';
import 'new_friend_challenge_sheet.dart';

/// Ajouter un ami : la feuille (e-mail exact, code, QR), puis la réponse.
///
/// Partagé par l'en-tête de la page et par l'onglet Amis vide : deux copies
/// d'un geste d'écriture finissent toujours par diverger sur ce qui compte
/// le moins et se voit le plus — le message rendu.
Future<void> addFriendFlow(
  BuildContext context,
  CommunityActions actions,
) async {
  final input = await showAddFriendSheet(context);
  if (input == null || !context.mounted) {
    return;
  }
  // Deux registres de confirmation, à dessein : une ADRESSE reste opaque
  // (le serveur ne révèle jamais qu'elle a un compte) ; un CODE se partage
  // volontairement, on confirme donc par le prénom — ou l'on dit
  // franchement qu'il ne mène nulle part.
  //
  // Ce dernier cas n'est pas une réussite : il prend le ton « erreur », et
  // se dit donc ici plutôt que par le retour du geste, qui vaut succès.
  final notices = AppNotices.of(context);
  await runCommunityGesture(context, () async {
    return switch (input) {
      AddFriendByEmail(:final email) => await () async {
        await actions.sendFriendRequest(email);
        return 'Si ce compte existe, il recevra ta demande.';
      }(),
      AddFriendByCode(:final code) => switch (await actions
          .sendFriendRequestByCode(code)) {
        final String name => 'Demande envoyée à $name.',
        null => () {
          notices.show(
            'Ce code ne mène à personne. Vérifie-le avec ton ami.',
            tone: AppNoticeTone.error,
          );
          return null;
        }(),
      },
    };
  });
}

/// Lance un défi à ses amis. La liste d'amis vient de l'écran, déjà
/// chargée : la feuille n'a pas à la redemander, et une feuille qui
/// attendrait le réseau pour s'ouvrir se lirait comme une lenteur.
Future<void> newFriendChallengeFlow(
  BuildContext context,
  CommunityActions actions,
  List<CommunityFriend> friends,
) async {
  final draft = await showNewFriendChallengeSheet(context, friends: friends);
  if (draft == null || !context.mounted) {
    return;
  }
  await runCommunityGesture(context, () async {
    await actions.createFriendChallenge(draft);
    return 'Ton défi est lancé. Tes amis vont le recevoir.';
  });
}
