import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_prefs.dart';
import '../../domain/mentor_word.dart';

/// Le bandeau du Mentor : qui parle, et ce qu'il dit.
///
/// Le dégradé VIOLET de l'application (`cta`), texte `neutral0` : le
/// Mentor parle depuis le thème de Carlys, pas depuis une carte grise —
/// et pas depuis le dégradé de marque multicolore, réservé aux
/// célébrations de franchissement (préférence actée le 18/09/2026).
class MentorBandeau extends StatelessWidget {
  const MentorBandeau({required this.mot, required this.frequence, super.key});

  /// Le mot du moment, `null` quand le Mentor se tait (interventions
  /// coupées) : le bandeau ne garde alors que l'identité.
  final MentorWord? mot;

  final MentorFrequency? frequence;

  String get _cadence {
    if (mot?.estCelebration ?? false) {
      return 'Il fête un cap avec toi';
    }
    return switch (frequence) {
      MentorFrequency.quotidienne => 'Son mot du jour',
      _ => 'Son mot de la semaine',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        gradient: AppColors.cta,
        borderRadius: AppRadius.cardSecondaryAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neutral0.withValues(alpha: 0.16),
                ),
                child: const Icon(
                  AppIcons.mentor,
                  size: 28,
                  color: AppColors.neutral0,
                ),
              ),
              const SizedBox(width: AppSpacing.gapRow),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ton guide',
                      style: AppTypography.label.copyWith(
                        color: AppColors.neutral0.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Le Mentor Carlys',
                      style: AppTypography.title.copyWith(
                        color: AppColors.neutral0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (mot != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              mot!.message,
              style: AppTypography.quote.copyWith(color: AppColors.neutral0),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _cadence.toUpperCase(),
              style: AppTypography.labelMono.copyWith(
                color: AppColors.neutral0.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
