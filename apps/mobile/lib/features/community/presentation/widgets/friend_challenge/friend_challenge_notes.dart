import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/friend_challenge.dart';
import 'friend_challenge_wording.dart';

/// La règle du jeu, puis le mot de celui qui a lancé le défi.
///
/// La maquette posait ici une « Récompense : +150 points pour chaque
/// participant » : un défi entre amis ne rapporte rien, et le dire
/// autrement mentirait (principe 5). Le bloc dit donc COMMENT on joue.
/// Le message n'apparaît que s'il existe : il est facultatif à la création.
class FriendChallengeNotes extends StatelessWidget {
  const FriendChallengeNotes({required this.challenge, super.key});

  final FriendChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final message = challenge.message;
    final createdAt = challenge.createdAt;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            icon: AppIcons.challengeRules,
            title: 'Comment ça se joue',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rule in friendChallengeRules(challenge))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      rule,
                      style: AppTypography.body.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (message != null) ...[
            const Divider(height: 1, color: AppColors.darkBorder),
            _Section(
              icon: AppIcons.challengeMessage,
              title: 'Message de ${challenge.creatorDisplayName}',
              trailing: createdAt == null
                  ? null
                  : friendChallengeMessageTime(createdAt),
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: AppColors.darkBackground,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Text(
                    '« $message »',
                    style: AppTypography.body.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Une section du bloc : une icône sur une plaque, un titre, une heure
/// facultative, et le contenu.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final Widget child;

  static const double _plateSize = 48;
  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    final trailingText = trailing;

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _plateSize,
              height: _plateSize,
              decoration: const BoxDecoration(
                color: AppColors.darkBackground,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(icon, size: _iconSize, color: AppColors.primaryLight),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: AppTypography.subheading.copyWith(
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                        ),
                      ),
                      if (trailingText != null)
                        Text(
                          trailingText,
                          style: AppTypography.label.copyWith(
                            color: AppColors.darkTextTertiary,
                          ),
                        ),
                    ],
                  ),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
