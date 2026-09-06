import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/community_moderation.dart';

/// Une personne bloquée : son nom, depuis quand, et le seul geste possible,
/// lever le blocage. Débloquer ne rétablit rien : l'amitié se redemande, et
/// le mot de retour le dit.
class BlockedUserCard extends StatelessWidget {
  const BlockedUserCard({
    required this.user,
    required this.onUnblock,
    super.key,
  });

  final BlockedUser user;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: AppColors.darkTextTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                Text(
                  'Ne te voit plus · ${formatRelativeTime(user.blockedAt)}',
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppButton(
            label: 'Débloquer',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            semanticLabel: 'Débloquer ${user.displayName}',
            onPressed: onUnblock,
          ),
        ],
      ),
    );
  }
}
