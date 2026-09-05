import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';

/// Un défi : nature, titre, progression COLLECTIVE, participants, échéance.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    required this.challenge,
    required this.onToggle,
    super.key,
  });

  final CommunityChallenge challenge;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final daysLeft = challenge.endsAt.difference(DateTime.now()).inDays;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                challenge.kind == ChallengeKind.sport
                    ? AppIcons.workout
                    : Icons.school_outlined,
                size: 18,
                color: challenge.kind == ChallengeKind.sport
                    ? AppColors.accent
                    : AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppSectionLabel(challenge.kind.label),
              const Spacer(),
              Text(
                daysLeft <= 0 ? 'dernier jour' : 'J−$daysLeft',
                style: AppTypography.labelMono.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            challenge.title,
            style: AppTypography.subheading.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            challenge.description,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // La progression est celle du GROUPE : la barre raconte l'effort
          // commun, pas la part de l'utilisateur.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: challenge.progress,
              minHeight: 6,
              backgroundColor: AppColors.darkBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${challenge.participants} participants',
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
              const Spacer(),
              AppButton(
                label: challenge.joined ? 'Quitter' : 'Participer',
                variant: challenge.joined
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: onToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
