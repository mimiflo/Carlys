import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';
import 'community_overflow_menu.dart';

/// Un mot reçu dans le fil : qui, quoi, quand.
///
/// Le fil ne contient que ce que J'AI reçu : « Supprimer » est donc
/// toujours permis (le destinataire retire ce qu'il ne veut plus lire), et
/// « Bloquer » comme « Signaler » visent l'auteur du mot.
///
/// « Bloquer » compte double ici : retirer un ami ne retire pas les mots
/// déjà reçus, donc l'auteur d'un mot blessant n'a plus de carte d'ami une
/// fois l'amitié rompue. Sans cette entrée, il n'existerait plus aucun
/// chemin pour le bloquer.
class EncouragementTile extends StatelessWidget {
  const EncouragementTile({
    required this.encouragement,
    required this.onDelete,
    required this.onBlock,
    required this.onReport,
    super.key,
  });

  final Encouragement encouragement;

  /// « Supprimer » : le mot quitte MON fil, l'auteur n'en sait rien.
  final VoidCallback onDelete;

  /// « Bloquer » : l'auteur du mot ne peut plus rien, et n'en saura rien.
  final VoidCallback onBlock;

  /// « Signaler » : un mot à l'équipe Carlys, à l'insu de l'auteur.
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
                    label: 'Bloquer',
                    icon: Icons.block_rounded,
                    destructive: true,
                    onSelected: onBlock,
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
