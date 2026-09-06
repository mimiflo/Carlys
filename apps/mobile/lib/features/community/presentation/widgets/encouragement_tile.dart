import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';
import 'community_overflow_menu.dart';

/// Un mot reçu dans le fil : qui, quoi, quand.
///
/// Le fil ne contient que ce que J'AI reçu : « Supprimer » est donc
/// toujours permis (le destinataire retire ce qu'il ne veut plus lire), et
/// « Signaler » vise l'auteur du mot.
class EncouragementTile extends StatelessWidget {
  const EncouragementTile({
    required this.encouragement,
    required this.onDelete,
    required this.onReport,
    super.key,
  });

  final Encouragement encouragement;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 16,
                color: AppColors.affection,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  encouragement.fromName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              Text(
                formatRelativeTime(encouragement.sentAt),
                style: AppTypography.labelMono.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              CommunityOverflowMenu(
                tooltip: 'Options du message de ${encouragement.fromName}',
                actions: [
                  CommunityMenuAction(
                    label: 'Supprimer',
                    icon: AppIcons.delete,
                    onSelected: onDelete,
                  ),
                  CommunityMenuAction(
                    label: 'Signaler',
                    icon: Icons.flag_outlined,
                    onSelected: onReport,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            encouragement.message,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
