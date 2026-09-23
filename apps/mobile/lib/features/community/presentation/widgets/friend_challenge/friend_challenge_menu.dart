import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/friend_challenge.dart';
import 'friend_challenge_gestures.dart';

/// Une entrée du menu « … » de l'écran d'un défi.
typedef FriendChallengeMenuEntry = ({
  String label,
  IconData icon,
  void Function(BuildContext context) run,
});

/// Ce que le menu propose, selon qui je suis dans le défi.
///
///  - « Signaler ce défi » : le titre et le message sont les mots de son
///    créateur ; on ne se signale pas soi-même, et sans créateur connu
///    (serveur plus ancien), il n'y a personne à signaler.
///  - « Quitter le défi » : seulement une fois dedans et tant qu'il court.
///    Une invitation se refuse en bas de l'écran, pas ici.
List<FriendChallengeMenuEntry> friendChallengeMenuEntries(
  FriendChallenge challenge,
  FriendChallengeGestures gestures, {
  required VoidCallback onLeft,
}) {
  final creator = challenge.creator;
  final inside =
      challenge.myStatus == FriendChallengeMemberStatus.accepted &&
      !challenge.isOver;
  return [
    if (creator != null && !creator.isMe)
      (
        label: 'Signaler ce défi',
        icon: AppIcons.report,
        run: (context) => gestures.report(context, challenge),
      ),
    if (inside)
      (
        label: 'Quitter le défi',
        icon: AppIcons.logout,
        run: (context) => gestures.leave(context, challenge, onLeft: onLeft),
      ),
  ];
}

/// Ouvre le menu en feuille : chaque entrée referme la feuille, PUIS agit
/// depuis l'écran — une confirmation ouverte depuis la feuille mourrait
/// avec elle.
Future<void> showFriendChallengeMenu(
  BuildContext context,
  List<FriendChallengeMenuEntry> entries,
) async {
  final chosen = await showAppSheet<FriendChallengeMenuEntry>(
    context,
    style: AppSheetStyle.picker,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in entries)
            AppListRow(
              title: entry.label,
              leading: entry.icon,
              onTap: () => Navigator.of(sheetContext).pop(entry),
            ),
        ],
      ),
    ),
  );
  if (chosen != null && context.mounted) {
    chosen.run(context);
  }
}
