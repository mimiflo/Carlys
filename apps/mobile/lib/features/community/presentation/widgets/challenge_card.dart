import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
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
                    : AppIcons.academyOutline,
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
          if (challenge.unit.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              // Ce que la barre MESURE, en toutes lettres. Sans elle, une
              // barre aux deux tiers ne disait ni de quoi ni combien.
              '${formatThousands(challenge.totalContribution)} / '
              '${formatThousands(challenge.target)} ${challenge.unit}',
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // Le compte à gauche, le bouton à droite quand ils tiennent côte à
          // côte ; le bouton passe dessous sinon, au lieu de sortir de la
          // carte (texte ×2). Toute la largeur, sinon le `Wrap` se réduit à
          // ses enfants (la colonne ne l'étire pas) et le bouton se colle
          // au compte au lieu d'aller à droite.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  '${challenge.participants} participants',
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
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
          ),
        ],
      ),
    );
  }
}
