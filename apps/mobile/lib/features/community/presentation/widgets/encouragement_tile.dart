import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';

/// Un mot reçu dans le fil : qui, quoi, quand.
class EncouragementTile extends StatelessWidget {
  const EncouragementTile({required this.encouragement, super.key});

  final Encouragement encouragement;

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
              Text(
                encouragement.fromName,
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                formatRelativeTime(encouragement.sentAt),
                style: AppTypography.labelMono.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
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
