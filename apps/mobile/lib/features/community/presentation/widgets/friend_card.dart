import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';
import 'community_overflow_menu.dart';

/// Un ami : nom, et — SEULEMENT s'il partage sa progression — sa série et
/// ses séances de la semaine. Le profil privé ne montre que le nom : la
/// séparation public/privé n'est pas un réglage d'affichage, les données
/// privées ne sont même pas dans l'entité.
///
/// Le menu « plus d'options » porte les gestes de protection ; la carte ne
/// fait que les proposer, l'enchaînement (confirmation, appel, retour) est
/// à l'appelant.
class FriendCard extends StatelessWidget {
  const FriendCard({
    required this.friend,
    required this.onEncourage,
    required this.onRemove,
    required this.onBlock,
    required this.onReport,
    super.key,
  });

  final CommunityFriend friend;
  final VoidCallback onEncourage;

  /// « Retirer » : l'amitié cesse, l'autre pourra redemander.
  final VoidCallback onRemove;

  /// « Bloquer » : l'autre ne peut plus rien, et n'en saura rien.
  final VoidCallback onBlock;

  /// « Signaler » : un mot à l'équipe Carlys, à l'insu de l'autre.
  final VoidCallback onReport;

  static const double _avatarSize = 44;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          // Le même disque que dans le classement de la ligue : sur une même
          // page, une personne a un seul visage.
          AppInitialAvatar(name: friend.displayName, size: _avatarSize),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                Text(
                  friend.sharesProgress
                      ? '${friend.streakDays} j de série · '
                            '${friend.weeklySessions} séances cette semaine'
                      : 'Profil privé',
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEncourage,
            tooltip: 'Encourager',
            icon: const Icon(AppIcons.encourage, color: AppColors.accent),
          ),
          CommunityOverflowMenu(
            tooltip: 'Options pour ${friend.displayName}',
            actions: [
              CommunityMenuAction(
                label: 'Retirer',
                icon: AppIcons.deleteAccount,
                onSelected: onRemove,
              ),
              CommunityMenuAction(
                label: 'Bloquer',
                icon: AppIcons.block,
                destructive: true,
                onSelected: onBlock,
              ),
              CommunityMenuAction(
                label: 'Signaler',
                icon: AppIcons.report,
                onSelected: onReport,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
