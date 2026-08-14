import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../community/domain/entities/community.dart';

/// La « petite notif » communautaire de l'accueil : le dernier mot reçu,
/// en une ligne, qui mène à l'onglet Communauté. Elle n'existe que s'il y a
/// réellement quelque chose à dire — jamais de carte vide.
class CommunityNudgeCard extends StatelessWidget {
  const CommunityNudgeCard({required this.encouragement, super.key});

  final Encouragement encouragement;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go(AppRoutes.community),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: AppColors.affection),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionLabel('${encouragement.fromName} t’encourage'),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  encouragement.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.darkTextTertiary,
          ),
        ],
      ),
    );
  }
}
