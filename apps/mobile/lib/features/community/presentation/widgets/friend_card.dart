import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';

/// Un ami : nom, et — SEULEMENT s'il partage sa progression — sa série et
/// ses séances de la semaine. Le profil privé ne montre que le nom : la
/// séparation public/privé n'est pas un réglage d'affichage, les données
/// privées ne sont même pas dans l'entité.
class FriendCard extends StatelessWidget {
  const FriendCard({
    required this.friend,
    required this.onEncourage,
    super.key,
  });

  final CommunityFriend friend;
  final VoidCallback onEncourage;

  @override
  Widget build(BuildContext context) {
    final initial = friend.displayName.isEmpty
        ? '?'
        : friend.displayName.characters.first.toUpperCase();

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: AppColors.violetRamp,
              borderRadius: AppRadius.avatarAll,
            ),
            child: Text(
              initial,
              style: AppTypography.subheading.copyWith(
                color: AppColors.neutral0,
              ),
            ),
          ),
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
            icon: const Icon(
              Icons.volunteer_activism_outlined,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
