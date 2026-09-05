import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';

/// Une demande d'ami reçue : qui, quand, et deux réponses possibles.
class FriendRequestCard extends StatelessWidget {
  const FriendRequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
    super.key,
  });

  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.person_add_alt_1_outlined, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fromDisplayName,
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                Text(
                  'veut devenir ton ami · '
                  '${formatRelativeTime(request.createdAt)}',
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDecline,
            tooltip: 'Refuser',
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.darkTextTertiary,
            ),
          ),
          IconButton(
            onPressed: onAccept,
            tooltip: 'Accepter',
            icon: const Icon(Icons.check_rounded, color: AppColors.success),
          ),
        ],
      ),
    );
  }
}
