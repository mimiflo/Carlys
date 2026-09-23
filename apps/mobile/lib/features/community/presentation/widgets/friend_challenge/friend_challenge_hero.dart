import 'package:flutter/material.dart';

import '../../../../../core/utilities/formatting.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/friend_challenge.dart';
import 'friend_challenge_facts.dart';
import 'friend_challenge_wording.dart';

/// L'en-tête d'un défi entre amis, d'après la maquette du 23 septembre
/// 2026 : l'étiquette et le compte à rebours, le titre, qui défie qui, deux
/// repères (les participants, la fin), puis la rangée de faits. Le
/// troisième repère de la maquette, « suivi en temps réel », n'est pas
/// repris : le classement se relit à chaque ouverture, il n'est pas poussé
/// en direct, et la règle du jeu le dit plus bas.
///
/// Le fond est un dégradé violet ([AppColors.challengeHero]) sous une
/// haltère en filigrane : la photographie de la maquette viendra s'y fondre
/// quand elle sera fournie — elle n'existe pas encore dans l'application.
class FriendChallengeHero extends StatelessWidget {
  const FriendChallengeHero({required this.challenge, super.key});

  final FriendChallenge challenge;

  static const double _watermarkSize = 150;
  static const double _badgeSize = 36;
  static const double _badgeIconSize = 20;
  static const double _originIconSize = 20;

  @override
  Widget build(BuildContext context) {
    final end = formatDayMonth(challenge.endsAt);

    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.challengeHero,
          borderRadius: AppRadius.lgAll,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.darkBorder),
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: Stack(
            children: [
              // Sous la pastille du compte à rebours, jamais contre elle.
              const Positioned(
                right: -AppSpacing.lg,
                top: AppSpacing.xxl,
                child: ExcludeSemantics(
                  child: Icon(
                    AppIcons.workout,
                    size: _watermarkSize,
                    color: AppColors.primaryCardStrong,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(),
                        const SizedBox(height: AppSpacing.sm),
                        Semantics(
                          header: true,
                          child: Text(
                            challenge.title,
                            style: AppTypography.resized(
                              AppTypography.display,
                              28,
                            ).copyWith(color: AppColors.darkTextPrimary),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _origin(),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _Landmark(
                              icon: AppIcons.community,
                              label: _participants(),
                            ),
                            _Landmark(
                              icon: AppIcons.calendarOutline,
                              label: challenge.isOver
                                  ? 'Fini le $end'
                                  : 'Fin le $end',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.darkBorder),
                  FriendChallengeFacts(challenge: challenge),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label() {
    return Row(
      children: [
        Container(
          width: _badgeSize,
          height: _badgeSize,
          decoration: const BoxDecoration(
            color: AppColors.primaryBadgeBg,
            borderRadius: AppRadius.smAll,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.primaryBadgeBorder),
            ),
          ),
          child: const Icon(
            AppIcons.community,
            size: _badgeIconSize,
            color: AppColors.primaryLight,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'DÉFI ENTRE AMIS',
            style: AppTypography.labelMono.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
        ),
        AppPill(
          label: friendChallengeCountdown(challenge),
          tone: AppPillTone.primary,
          mono: true,
        ),
      ],
    );
  }

  Widget _origin() {
    return Row(
      children: [
        const Icon(
          AppIcons.workout,
          size: _originIconSize,
          color: AppColors.primaryLight,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            friendChallengeOrigin(challenge),
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
        ),
      ],
    );
  }

  String _participants() {
    final count = challenge.participants.length;
    return '$count ${count <= 1 ? 'participant' : 'participants'}';
  }
}

/// Un repère de l'en-tête : une icône violette, un mot, sur une plaque
/// sombre.
class _Landmark extends StatelessWidget {
  const _Landmark({required this.icon, required this.label});

  final IconData icon;
  final String label;

  static const double _iconSize = 18;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkBackground,
        borderRadius: AppRadius.mdAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _iconSize, color: AppColors.primaryLight),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
